xquery version "3.0";

(: 
 : Defines all the RestXQ endpoints used by the XForms.
 :)
module namespace demo="http://exist-db.org/apps/restxq/demo";

import module namespace config="http://exist-db.org/xquery/apps/config" at "../../modules/config.xqm";

declare namespace rest="http://exquery.org/ns/restxq";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

declare variable $demo:data := $config:app-root || "/data/addresses";

(:~
 : List all addresses and return them as XML.
 :)
declare
    %rest:GET
    %rest:path("/address")
    %rest:produces("application/xml", "text/xml")
function demo:addresses() {
    <addresses>
    {
        for $address in collection($config:app-root || "/data/addresses")/address
        return
            $address
    }
    </addresses>
};

(:~
 : Test: list all addresses in JSON format. For this function to be chosen,
 : the client should send an Accept header containing application/json.
 :)
(:declare:)
(:    %rest:GET:)
(:    %rest:path("/address"):)
(:    %rest:produces("application/json"):)
(:    %output:media-type("application/json"):)
(:    %output:method("json"):)
(:function demo:addresses-json() {:)
(:    demo:addresses():)
(:};:)

(:~
 : Retrieve an address identified by uuid.
 :)
declare 
    %rest:GET
    %rest:path("/address/{$id}")
function demo:get-address($id as xs:string*) {
    collection($demo:data)/address[@id = $id]
};

(:~
 : Search addresses using a given field and a (lucene) query string.
 :)
declare 
    %rest:GET
    %rest:path("/search")
    %rest:form-param("query", "{$query}", "")
    %rest:form-param("field", "{$field}", "name")
function demo:search-addresses($query as xs:string*, $field as xs:string*) {
    <addresses>
    {
        if ($query != "") then
            switch ($field)
                case "name" return
                    collection($demo:data)/address[ngram:contains(name, $query)]
                case "street" return
                    collection($demo:data)/address[ngram:contains(street, $query)]
                case "city" return
                    collection($demo:data)/address[ngram:contains(city, $query)]
                default return
                    collection($demo:data)/address[ngram:contains(., $query)]
        else
            collection($demo:data)/address
    }
    </addresses>
};

(:~
 : Update an existing address or store a new one. The address XML is read
 : from the request body.
 :)
declare
    %rest:PUT("{$content}")
    %rest:path("/address")
function demo:create-or-edit-address($content as node()*) {
    let $id := ($content/address/@id, util:uuid())[1]
    let $data :=
        <address id="{$id}">
        { $content/address/* }
        </address>
    let $log := util:log("DEBUG", "Storing data into " || $demo:data)
    let $stored := xmldb:store($demo:data, $id || ".xml", $data)
    return
        demo:addresses()
};

(:~
 : Delete an address identified by its uuid.
 :)
declare
    %rest:DELETE
    %rest:path("/address/{$id}")
function demo:delete-address($id as xs:string*) {
    xmldb:remove($demo:data, $id || ".xml"),
    demo:addresses()
};