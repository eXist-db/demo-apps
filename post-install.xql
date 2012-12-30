xquery version "3.0";

import module namespace xdb="http://exist-db.org/xquery/xmldb";

(: The following external variables are set by the repo:deploy function :)

(: the target collection into which the app is deployed :)
declare variable $target external;

(: Allow uploads to binary collection :)
sm:chmod(xs:anyURI($target || "/data/binary"), "rwxrwxrwx"),
(: Allow changes to addresses collection :)
sm:chmod(xs:anyURI($target || "/data/addresses"), "rwxrwxrwx"),
for $resource in xmldb:get-child-resources($target || "/data/addresses")
return
    sm:chmod(xs:anyURI($target || "/data/addresses/" || $resource), "rwxrwxrwx")