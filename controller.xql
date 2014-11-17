xquery version "1.0";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace login="http://exist-db.org/xquery/login" at "resource:org/exist/xquery/modules/persistentlogin/login.xql";

declare variable $exist:path external;
declare variable $exist:resource external;
declare variable $exist:controller external;
declare variable $exist:prefix external;

if ($exist:path eq "") then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="{concat(request:get-uri(), '/')}"/>
    </dispatch>

else if ($exist:path eq "/") then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="index.html"/>
    </dispatch>

(:  Protected resource: user is required to log in with valid credentials.
    If the login fails or no credentials were provided, the request is redirected
    to the login.html page. :)
else if ($exist:resource eq 'protected.html') then (
    login:set-user("org.exist.demo.login", (), false()),
    if (request:get-attribute("org.exist.demo.login.user")) then
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
            <view>
                <forward url="{$exist:controller}/modules/view.xql">
                    <set-attribute name="$exist:prefix" value="{$exist:prefix}"/>
                    <set-attribute name="$exist:controller" value="{$exist:controller}"/>
                    <set-header name="Cache-Control" value="no-cache"/>
                </forward>
            </view>
        </dispatch>
    else
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
            <forward url="login.html"/>
            <view>
                <forward url="{$exist:controller}/modules/view.xql">
                    <set-attribute name="$exist:prefix" value="{$exist:prefix}"/>
                    <set-attribute name="$exist:controller" value="{$exist:controller}"/>
                    <set-header name="Cache-Control" value="no-cache"/>
                </forward>
            </view>
        </dispatch>
)

(: Pass all requests to HTML files through view.xql, which handles HTML templating :)
else if (ends-with($exist:resource, ".html")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <view>
            <forward url="{$exist:controller}/modules/view.xql">
                {login:set-user("org.exist.demo.login", (), false())}
                <set-attribute name="$exist:prefix" value="{$exist:prefix}"/>
                <set-attribute name="$exist:controller" value="{$exist:controller}"/>
                <set-header name="Cache-Control" value="no-cache"/>
            </forward>
        </view>
        <error-handler>
            <forward url="{$exist:controller}/error-page.html" method="get"/>
            <forward url="{$exist:controller}/modules/view.xql"/>
        </error-handler>
    </dispatch>

else if (ends-with($exist:resource, ".xql")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <set-header name="Cache-Control" value="no-cache"/>
    </dispatch>
    
else if (contains($exist:path, "/$shared/")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="/shared-resources/{substring-after($exist:path, '/$shared/')}">
            <set-header name="Cache-Control" value="max-age=3600, must-revalidate"/>
        </forward>
    </dispatch>

(: images, css are contained in the top /resources/ collection. :)
(: Relative path requests from sub-collections are redirected there :)
else if (contains($exist:path, "/resources/")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/resources/{substring-after($exist:path, '/resources/')}">
            <set-header name="Cache-Control" value="max-age=3600, must-revalidate"/>
        </forward>
    </dispatch>

else
    <ignore xmlns="http://exist.sourceforge.net/NS/exist">
        <cache-control cache="yes"/>
    </ignore>