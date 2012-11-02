xquery version "1.0";

(: 
 : Main controller. Uses restxq to keep the code clean. This only works with the XQuery
 : implementation of RestXQ though.
 :)
import module namespace restxq="http://exist-db.org/xquery/restxq" at "../../modules/restxq.xql";
import module namespace demo="http://exist-db.org/apps/restxq/demo" at "restxq-demo.xql";

(: Need to use a different namespace here to prevent the restxq java triggger 
 : from evaluating the annotations. :)
declare namespace restx="http://exist-db.org/ns/rest/annotation/xquery";

declare variable $exist:path external;

(:~
 : Redirect requests for / to index.html.
 : 
 : If the restxq module is called through the controller.xql, functions
 : may either return an arbitrary sequence, or an XML fragment with instructions
 : for the controller. This fragment has to be in the "exist" namespace.
 :)
declare
    %restx:GET
    %restx:path("/")
function local:root() {
    (: forward root path to index.xql :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="index.html"/>
    </dispatch>
};

(:~
 : Pages ending with .html are run through view.xql to
 : expand templates.
 :)
declare
    %restx:GET
    %restx:path("{$page}.html")
function local:html($page as xs:string) {
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <view>
            <forward url="../../modules/view.xql"/>
        </view>
        <error-handler>
    		<forward url="error-page.html" method="get"/>
			<forward url="../../modules/view.xql"/>
		</error-handler>
    </dispatch>
};

(:~
 : Fallback: this function is called for any GET request
 : not matching any of the previous functions in this module.
 : 
 : Just let the URL rewriting controller handle the request.
 :)
declare
    %restx:GET
function local:default() {
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <cache-control cache="yes"/>
    </dispatch>
};

declare
    %restx:GET
    %restx:path("/libs/{$path}")
function local:libs($path as xs:string) {
(: Requests for javascript libraries are resolved to the file system :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="/{$path}" absolute="yes">
            <set-attribute name="betterform.filter.ignoreResponseBody" value="true"/>
        </forward>
    </dispatch>
};

declare
    %restx:GET
    %restx:path("/resources/{$path}")
function local:resources($path as xs:string) {
    (: images, css are contained in the top /resources/ collection. :)
    (: Relative path requests from sub-collections are redirected there :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/../../resources/{$path}"/>
    </dispatch>
};
    
let $functions := (util:list-functions(), util:list-functions("http://exist-db.org/apps/restxq/demo"))
return
    (: All URL paths are processed by the restxq module :)
    restxq:process($exist:path, $functions)