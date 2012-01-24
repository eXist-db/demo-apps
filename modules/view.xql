xquery version "1.0";

import module namespace templates="http://exist-db.org/xquery/templates" at "templates.xql";

declare option exist:serialize "method=html5 media-type=text/html";

declare variable $modules :=
    <modules>
        <module prefix="i18n" uri="http://exist-db.org/xquery/i18n/templates" at="i18n-templates.xql"/>
        <module prefix="config" uri="http://exist-db.org/xquery/apps/config" at="config.xql"/>
        <module prefix="demo" uri="http://exist-db.org/apps/demo" at="demo.xql"/>
        <module prefix="cex" uri="http://exist-db.org/apps/demo/cex" at="cex.xql"/>
        <module prefix="shakespeare" uri="http://exist-db.org/apps/demo/shakespeare" at="shakespeare.xql"/>
        <module prefix="guess" uri="http://exist-db.org/apps/demo/guess" at="../examples/web/guess-templates.xql"/>
    </modules>;

let $content := request:get-data()
return
    templates:apply($content, $modules, ())