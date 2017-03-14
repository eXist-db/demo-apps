module namespace cex="http://exist-db.org/apps/demo/cex";

import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace kwic="http://exist-db.org/xquery/kwic"
at "resource:org/exist/xquery/lib/kwic.xql";

declare function cex:query($node as node()*, $model as map(*), $query as xs:string?) {
    <div class="cex-results">
        {
            for $result in ft:search("/db/", concat('page:', $query))/search
            let $fields := $result/field
            (: Retrieve title from title field if available :)
            let $titleField := ft:get-field($result/@uri, "Title")
            let $title := if ($titleField) then $titleField else replace($result/@uri, "^.*/([^/]+)$", "$1")
            let $contentType := ft:get-field($result/@uri, "Content-Type")
            return
                <div class="item">
                    <p class="itemhead">{$title} - Score: {$result/@score/string()}</p>
                    <p class="itemhead">Type: { $contentType }</p>
                    <p class="itemhead">Found matches in {count($fields[.//exist:match])} of the {count($fields)} page{if (count($fields) gt 1) then 's' else ''} of the document. {if (count($fields[.//exist:match]) gt 10) then 'Only matches from the first 10 pages with matches are shown.' else ''}</p>
                    {
                        let $groupsRegex := "\[\[([0-9]+)"
                        for $field in subsequence($fields[.//exist:match], 1, 10)
                            let $page := analyze-string($field, $groupsRegex)//fn:group/string()
                            return
                                <p>
                                    { concat("page ", $page) }
                                    {kwic:summarize($field, <config width="40"/>)}
                                </p>
                    }
                </div>
        }
    </div>
};
