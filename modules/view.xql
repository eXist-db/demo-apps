xquery version "3.0";

import module namespace templates="http://exist-db.org/xquery/templates" at "templates.xql";

(: The following modules provide functions which will be called by the templating :)
import module namespace shakespeare="http://exist-db.org/apps/demo/shakespeare" at "shakespeare.xql";
import module namespace i18n="http://exist-db.org/xquery/i18n/templates" at "i18n-templates.xql";
import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace demo="http://exist-db.org/apps/demo" at "demo.xql";
import module namespace guess="http://exist-db.org/apps/demo/guess" at "../examples/web/guess-templates.xql";
import module namespace cex="http://exist-db.org/apps/demo/cex" at "cex.xql";

declare option exist:serialize "method=html5 media-type=text/html";

let $lookup := function($functionName as xs:string) {
    try {
        function-lookup(xs:QName($functionName), 3)
    } catch * {
        ()
    }
}
let $content := request:get-data()
return
    templates:apply($content, $lookup, ())