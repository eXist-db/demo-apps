xquery version "1.0";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace xdb = "http://exist-db.org/xquery/xmldb";

declare variable $exist:path external;
declare variable $exist:resource external;
declare variable $exist:controller external;
declare variable $exist:prefix external;

declare variable $logout := request:get-parameter("logout", ());

declare function local:is-logged-in() {
    exists(local:credentials-from-session())
};

(:~
    Retrieve current user credentials from HTTP session
:)
declare function local:credentials-from-session() as xs:string* {
    (session:get-attribute("demo.user"), session:get-attribute("demo.password"))
};

(:~
    Store user credentials to session for future use. Return an XML
    fragment to pass user and password to the query.
:)
declare function local:set-credentials($user as xs:string, $password as xs:string?) as element()+ {
    session:set-attribute("demo.user", $user), 
    session:set-attribute("demo.password", $password),
    <set-attribute name="xquery.user" value="{$user}"/>,
    <set-attribute name="xquery.password" value="{$password}"/>
};

(:~
    Check if login parameters were passed in the request. If yes, try to authenticate
    the user and store credentials into the session. Clear the session if parameter
    "logout" is set.
    
    The function returns an XML fragment to be included into the dispatch XML or
    the empty set if the user could not be authenticated or the
    session is empty.
:)
declare function local:set-user() as element()* {
    session:create(),
    let $user := request:get-parameter("user", ())
    let $password := request:get-parameter("password", ())
    let $sessionCredentials := local:credentials-from-session()
    return
        if ($user) then
            let $loggedIn := xmldb:login("/db", $user, $password)
            return
                if ($loggedIn) then
                    local:set-credentials($user, $password)
                else
                    ()
        else if (exists($sessionCredentials)) then
            local:set-credentials($sessionCredentials[1], $sessionCredentials[2])
        else
            ()
};

declare function local:logout() as empty() {
    session:clear()
};


if ($logout) then
    local:logout()
else
    (),
if ($exist:path eq "/") then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="index.html"/>
    </dispatch>

(:  Protected resource: user is required to log in with valid credentials.
    If the login fails or no credentials were provided, the request is redirected
    to the login.xml page. :)
else if ($exist:resource eq 'protected.html') then
    let $login := local:set-user()
    return
        if ($login) then
            <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
                {$login}
                <view>
                    <forward url="{$exist:controller}/modules/view.xql">
                        <set-attribute name="$exist:prefix" value="{$exist:prefix}"/>
                        <set-attribute name="$exist:controller" value="{$exist:controller}"/>
                        <set-header name="CacheControl" value="no-cache"/>
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
                        <set-header name="CacheControl" value="no-cache"/>
                    </forward>
                </view>
            </dispatch>
    
(: Pass all requests to HTML files through view.xql, which handles HTML templating :)
else if (ends-with($exist:resource, ".html")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <view>
            <forward url="{$exist:controller}/modules/view.xql">
                <set-attribute name="$exist:prefix" value="{$exist:prefix}"/>
                <set-attribute name="$exist:controller" value="{$exist:controller}"/>
            </forward>
        </view>
        <error-handler>
            <forward url="{$exist:controller}/error-page.html" method="get"/>
            <forward url="{$exist:controller}/modules/view.xql"/>
        </error-handler>
    </dispatch>

(: Requests for javascript libraries are resolved to the file system :)
else if (contains($exist:path, "/libs/")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="/{substring-after($exist:path, '/libs/')}" absolute="yes"/>
    </dispatch>

(: images, css are contained in the top /resources/ collection. :)
(: Relative path requests from sub-collections are redirected there :)
else if (contains($exist:path, "/resources/")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/resources/{substring-after($exist:path, '/resources/')}"/>
    </dispatch>

else
    <ignore xmlns="http://exist.sourceforge.net/NS/exist">
        <cache-control cache="yes"/>
    </ignore>