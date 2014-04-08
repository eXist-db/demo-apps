xquery version "1.0";

(: 
 : Main controller.
 :)
import module namespace demo="http://exist-db.org/apps/restxq/demo" at "restxq-demo.xql";

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
