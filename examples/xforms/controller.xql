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
declare variable $exist:resource external;
declare variable $exist:controller external;

(:~
 : Redirect requests for / to demo.html.
 :)
if ($exist:path = "/") then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="demo.html?restxq={request:get-context-path()}/restxq/"/>
    </dispatch>

else if (ends-with($exist:resource, ".html")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <view>
            <forward url="../../modules/view.xql"/>
        </view>
        <error-handler>
    		<forward url="error-page.html" method="get"/>
			<forward url="../../modules/view.xql"/>
		</error-handler>
    </dispatch>


else if (starts-with($exist:path, ("/address", "/search"))) then
    let $functions := util:list-functions("http://exist-db.org/apps/restxq/demo")
    return
        (: All URL paths are processed by the restxq module :)
        restxq:process($exist:path, $functions)

else if (contains($exist:path, "/$shared/")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="/shared-resources/{substring-after($exist:path, '/$shared/')}">
            <set-header name="Cache-Control" value="max-age=3600, must-revalidate"/>
        </forward>
    </dispatch>

else if (starts-with($exist:path, "/resources")) then
    (: images, css are contained in the top /resources/ collection. :)
    (: Relative path requests from sub-collections are redirected there :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/../../{$exist:path}"/>
    </dispatch>

else
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <cache-control cache="yes"/>
    </dispatch>
