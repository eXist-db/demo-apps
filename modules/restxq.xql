(:
 :  RESTful Annotations for XQuery (RESTXQ) in plain XQuery. Temporary solution until
 :  the Java implementation is available.
 : 
 :  Copyright (C) 2012 Wolfgang Meier
 :  http://existsolutions.com
 :
 :  This program is free software; you can redistribute it and/or
 :  modify it under the terms of the GNU Lesser General Public License
 :  as published by the Free Software Foundation; either version 2
 :  of the License, or (at your option) any later version.
 :
 :  This program is distributed in the hope that it will be useful,
 :  but WITHOUT ANY WARRANTY; without even the implied warranty of
 :  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 :  GNU Lesser General Public License for more details.
 :
 :  You should have received a copy of the GNU Lesser General Public
 :  License along with this library; if not, write to the Free Software
 :  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 :
 :  $Id$
 :)

xquery version "3.0";

(:~
 : An implementation of RESTful Annotations for XQuery (RESTXQ) in plain
 : XQuery. Most of this code is standard XQuery 3.0 with map extension, 
 : except for the function used to inspect a function signature and the 
 : calls to the HTTP request module.
 : 
 : This started as a temporary solution until the Java implementation was
 : available, but I now use it as a quick fallback when I don't want to or 
 : cannot enable the restxq trigger.
 : 
 : @author Wolfgang Meier <wolfgang@existsolutions.com>
 :)
module namespace restxq="http://exist-db.org/xquery/restxq";

declare variable $restxq:NAMESPACE := "http://exquery.org/ns/restxq";
(: 
 : Define a second namespace for the annotations which can be used in cases
 : where annotations would conflict with the Java restxq.
 :)
declare variable $restxq:EXTENSION_NAMESPACE := "http://exist-db.org/ns/rest/annotation/xquery";

declare variable $restxq:OUTPUT_NAMESPACE :="http://www.w3.org/2010/xslt-xquery-serialization";

declare variable $restxq:WRONG_ARG_COUNT := QName($restxq:NAMESPACE, "wrong-number-of-arguments");
declare variable $restxq:TOO_MANY_ARGS := QName($restxq:NAMESPACE, "too-many-arguments");
declare variable $restxq:TYPE_ERROR := QName($restxq:NAMESPACE, "type-error");
declare variable $restxq:AMBIGUOUS := QName($restxq:NAMESPACE, "ambiguous");
declare variable $restxq:UNKNOWN := QName($restxq:NAMESPACE, "unknown-annotation");

declare variable $restxq:OUTPUT_MEDIA_TYPE := QName($restxq:OUTPUT_NAMESPACE, "media-type");
declare variable $restxq:OUTPUT_METHOD := QName($restxq:OUTPUT_NAMESPACE, "method");

declare variable $restxq:ERROR_IF_AMBIGUOUS := false();

(:~ 
 : Main entry point: takes a sequence of functions and tries to match them
 : against the current HTTP request by inspecting their %rest annotations.
 : 
 : @param $path-info the HTTP request path to compare with in %restxq:path. If empty,
 : we'll use the value returned by request:get-path-info(), i.e. any extra path
 : information in the URL after the path leading to the called XQuery. If you call
 : restxq from a controller.xql, you probably want to pass $exist:path as $path-info.
 : 
 : @param $functions the sequence of function items to inspect, usually obtained
 : by calling util:list-functions on a module URI.
 :)
declare function restxq:process($path-info as xs:string?, $functions as function(*)+) {
    let $params := map {
        "$restxq:path" :=
            if (exists($path-info)) then
                $path-info
            else
                request:get-path-info()
    }
    let $log := util:log("DEBUG", "Processing path " || $params("$restxq:path"))
    return
        restxq:function-by-annotation($functions, $params, function($function as function(*), $meta as element(function), $params as map(*)) {
            let $arguments := restxq:map-arguments($meta, $params)
            return (
                restxq:set-serialization($meta),
                util:log("DEBUG", "Calling function " || function-name($function)),
                restxq:call-with-args($function, $arguments)
            )
        })
};

(:~
 : Find functions with annotations matching the current HTTP request. Call the supplied
 : callback function for each matching function found.
 :)
declare %private function restxq:function-by-annotation($functions as function(*)+, $params as map(*),
    $callback as function(function(*), element(function), map(*)) as item()*) {
    (: Create a map first, so we can count how many functions match
     : and throw an error if there's more than one :)
    let $matchingFunctions :=
        for $function in $functions
        let $meta := util:inspect-function($function)
        let $annotations := $meta/annotation[@namespace = ($restxq:NAMESPACE, $restxq:EXTENSION_NAMESPACE)]
        return
            if (empty($annotations)) then
                ()
            else
                let $params := restxq:find-matching-annotations($annotations, $params)
                return
                    if (empty($params)) then
                        ()
                    else
                        map {
                            "function" := $function,
                            "meta" := $meta,
                            "params" := $params
                        }
    return
        (: More than one function found: throw an error :)
        if (count($matchingFunctions) > 1 and $restxq:ERROR_IF_AMBIGUOUS) then
            error($restxq:AMBIGUOUS, "More than one function matches the request: " || 
                string-join(for $f in $matchingFunctions return function-name($f("function")), ", "))
        else
            (: If there are multiple matching functions, choose the one with the larger
             : number of annotations. :)
            let $fOrdered :=
                for $f in $matchingFunctions
                order by count($f("meta")/annotation) descending
                return
                    $f
            for $f in $fOrdered[1]
            return
                $callback($f("function"), $f("meta"), $f("params"))
};

(:~ 
 : Process the given %rest annotation. Returns the empty sequence if the annotation
 : is constraining and does not match the current HTTP request, or a map of parameters
 : otherwise.
 :)
declare %private function restxq:match-annotation($anno as element(annotation), $params as map(*)) as map(*)? {
    let $method := substring-after($anno/@name, ":")
    return
        switch($method)
            case "path" return
                restxq:path($anno, $params)
            case "GET" case "DELETE" case "HEAD" return
                restxq:method($method, $anno, $params)
            case "POST" case "PUT" return
                restxq:post($anno, $method, $params)
            case "consumes" return
                restxq:consumes($anno, $params)
            case "produces" return
                restxq:produces($anno, $params)
            case "query-param" case "form-param" return
                restxq:query-param($anno, $params)
            case "header-param" return
                restxq:header-param($anno, $params)
            default return
                error($restxq:UNKNOWN, concat("Unknown annotation: ", $anno/@name))
};

(:~
 : Handles %restxq:GET, %restxq:DELETE
 :)
declare %private function restxq:method($method as xs:string, $anno as element(annotation), $params as map(*)) as map(*)? {
    if (upper-case(request:get-method()) = $method) then
        $params
    else
        ()
};

(:~
 : %restxq:POST(param)
 :)
declare %private function restxq:post($anno as element(annotation), $method as xs:string, $params as map(*)) {
    if (not(upper-case(request:get-method()) = $method)) then
        ()
    else
        let $value := $anno/value
        return
            if (empty($value)) then
                $params
            else
                let $var := restxq:extract-variable($value)
                return
                    if ($var) then
                        let $accessor := function() { request:get-data() }
                        return
                            map:new(($params, map:entry($var, $accessor)))
                    else
                        $params
};

(:~
 : %restxq:consumes(media-type1, media-type2)
 :)
declare %private function restxq:consumes($anno as element(annotation), $params as map(*)) as map(*)? {
    let $types := $anno/value/string()
    let $content-type := request:get-header("Content-Type")
    return
        (: = returns true if one of the items in the $types sequence is equal to $content-type :)
        if ($content-type = $types) then
            $params
        else
            ()
};

(:~
 : %restxq:produces(media-type1, media-type2)
 :)
declare %private function restxq:produces($anno as element(annotation), $params as map(*)) {
    let $header := request:get-header("Accept")
    let $header := if (contains($header, ";")) then substring-before($header, ";") else $header
    let $types := tokenize($header, "\s*,\s*")
    let $produces := $anno/value/string()
    let $produces := if (exists($produces)) then $produces else "text/xml"
    return
        if (some $type in $produces satisfies $type = $types) then
            $params
        else
            ()
};

(:~
 : %restxq:query-param(reqParam, funcParam, default)
 :)
declare %private function restxq:query-param($anno as element(annotation), $params as map(*)) as map(*)? {
    let $paramName := $anno/value[1]/string()
    let $var := restxq:extract-variable($anno/value[2]/string())
    let $default := if ($anno/value[3]) then $anno/value[3]/string() else ()
    let $param := request:get-parameter($paramName, $default)
    return
        map:new(($params, map:entry($var, $param)))
};

(:~
 : %restxq:header-param(reqParam, funcParam)
 :)
declare %private function restxq:header-param($anno as element(annotation), $params as map(*)) as map(*)? {
    let $headerName := $anno/value[1]/string()
    let $var := restxq:extract-variable($anno/value[2]/string())
    let $header := request:get-header($headerName)
    return
        map:new(($params, map:entry($var, $header)))
};

(:~
 : %restxq:path(path)
 :)
declare %private function restxq:path($anno as element(annotation), $params as map(*)) as map(*)? {
    let $path := $params("$restxq:path")
    let $annoPath := $anno/value[1]/string()
    let $match := restxq:match-path($params, $path, $annoPath)
    return
        $match
};

(:~
 : Compare the input path to a path template with (optional) variable substitutions.
 : Returns the empty sequence if the path does not match or a map containing
 : the substituted variables and their values.
 :)
declare %private function restxq:match-path($params as map(*), $input as xs:string, $template as xs:string) as map(*)? {
    let $regex := "^" || replace($template, "\{\$([^\}]+)\}", ".*") || "/?$"
    let $log := util:log("DEBUG", "$input: " || $input || " $template: " || $template || " $regex: " || $regex)
    return
        if (matches($input, $regex)) then
            let $groupsRegex := "^" || replace($template, "\{\$([^\}]+)\}", "(.*)") || "$"
            let $groups := subsequence(text:groups($input, $groupsRegex), 2)
            let $analyzed := analyze-string($template, "\{\$[^\}]+\}")
            return
                map:new((
                    $params,
                    map-pairs(function($group, $varExpr) {
                        let $var := replace($varExpr, "\{\$([^\}]+)\}", "$1")
                        return
                            map:entry($var, $group)
                    }, $groups, $analyzed//fn:match)
                ))
        else
            ()
};

(:~
 : Recursively inspect all rest annotations of a function and try to match them against the request.
 :)
declare %private function restxq:find-matching-annotations($annotations as element(annotation)*, $params as map(*)) {
    if (empty($annotations)) then
        $params
    else
        let $params := restxq:match-annotation(head($annotations), $params)
        return
            if (exists($params)) then
                let $tail := tail($annotations)
                return (
                    (: Bug: recursive call doesn't work if () is removed :)
                    (),
                    restxq:find-matching-annotations($tail, $params)
                )
            else
                ()
};

(:~
 : Try to fill in the function arguments using the values supplied in the paramter map.
 :)
declare %private function restxq:map-arguments($inspect as element(function), $params as map(*)) {
    $inspect/argument ! restxq:map-argument(., $params)
};

(:~
 : Try to fill a single function argument using the values supplied in the parameter map.
 : Attempts type conversion by casting the parameter to the required function argument type.
 :)
declare %private function restxq:map-argument($arg as element(argument), $params as map(*)) as function() as item()* {
    let $var := $arg/@var
    let $type := $arg/@type/string()
    return
        if (map:contains($params, $var)) then
            let $param := $params($var)
            let $value := if ($param instance of function(*)) then $param() else $param
            let $data :=
                try {
                    restxq:cast($value, $type)
                } catch * {
                    error($restxq:TYPE_ERROR, "Failed to cast parameter value '" || $value || "' to the required target type for " ||
                        "function parameter $" || $var || " of function " || ($arg/../@name) || ". Required type was: " ||
                        $type || ". " || $err:description)
                }
            return
                function() { $data }
        else
            error($restxq:TYPE_ERROR, "Cannot determine value for function parameter $" || $var)
};

declare %private function restxq:cast($values as item()*, $targetType as xs:string) {
    for $value in $values
    return
        if ($targetType != "xs:string" and string-length($value) = 0) then
            (: treat "" as empty sequence :)
            ()
        else
            switch ($targetType)
                case "xs:string" return
                    string($value)
                case "xs:integer" case "xs:int" case "xs:long" return
                    xs:integer($value)
                case "xs:decimal" return
                    xs:decimal($value)
                case "xs:float" case "xs:double" return
                    xs:double($value)
                case "xs:date" return
                    xs:date($value)
                case "xs:dateTime" return
                    xs:dateTime($value)
                case "xs:time" return
                    xs:time($value)
                case "element()" return
                    util:parse($value)/*
                case "text()" return
                    text { string($value) }
                default return
                    $value
};

(:~
 : Call the supplied function using the argument sequence. Arguments are provided
 : as function items, so we can 1) use sequences, 2) postpone argument computation
 : until the actual call.
 :)
declare %private function restxq:call-with-args($fn as function(*), $args as (function() as item()*)*) {
    switch (count($args))
        case 0 return
            $fn()
        case 1 return
            $fn($args[1]())
        case 2 return
            $fn($args[1](), $args[2]())
        case 3 return
            $fn($args[1](), $args[2](), $args[3]())
        case 4 return
            $fn($args[1](), $args[2](), $args[3](), $args[4]())
        case 5 return
            $fn($args[1](), $args[2](), $args[3](), $args[4](), $args[5]())
        case 6 return
            $fn($args[1](), $args[2](), $args[3](), $args[4](), $args[5](), $args[6]())
        case 7 return
            $fn($args[1](), $args[2](), $args[3](), $args[4](), $args[5](), $args[6](), $args[7]())
        case 8 return
            $fn($args[1](), $args[2](), $args[3](), $args[4](), $args[5](), $args[6](), $args[7](), $args[8]())
        default return
            error($restxq:TOO_MANY_ARGS, "Too many arguments to function " || function-name($fn))
};

declare %private function restxq:extract-variable($param as xs:string) as xs:string {
    if (matches($param, "\{\$[^\}]+\}")) then
        replace($param, "^.*\{\$([^\}]+)\}.*$", "$1")
    else
        ()
};

declare %private function restxq:get-annotation($meta as element(function), $annotation as xs:QName) as xs:string* {
    $meta/annotation[@namespace = namespace-uri-from-QName($annotation)]
        [substring-after(@name, ":") = local-name-from-QName($annotation)]/value/string()
};

declare %private function restxq:set-serialization($meta as element(function)) {
    let $serializeStr :=
        $meta/annotation[@namespace = $restxq:OUTPUT_NAMESPACE] !
            concat(substring-after(@name, ":"), "=", value[1]/string())
    return
        if (exists($serializeStr)) then
            util:declare-option("exist:serialize", string-join($serializeStr, " "))
        else
            ()
};