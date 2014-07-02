xquery version "3.0";

import module namespace xdb="http://exist-db.org/xquery/xmldb";

import module namespace xrest="http://exquery.org/ns/restxq/exist" at "java:org.exist.extensions.exquery.restxq.impl.xquery.exist.ExistRestXqModule";

(: The following external variables are set by the repo:deploy function :)

(: the target collection into which the app is deployed :)
declare variable $target external;

(: Create 'contacts/data' collection and then make writable :)
xmldb:create-collection($target || "/examples/contacts", "data"),
sm:chmod(xs:anyURI($target || "/examples/contacts/data"), "rwxrwxrwx"),
(: Allow uploads to binary collection :)
sm:chmod(xs:anyURI($target || "/data/binary"), "rwxrwxrwx"),
(: Allow changes to addresses collection :)
sm:chmod(xs:anyURI($target || "/data/addresses"), "rwxrwxrwx"),
for $resource in xmldb:get-child-resources($target || "/data/addresses")
return
    sm:chmod(xs:anyURI($target || "/data/addresses/" || $resource), "rwxrwxrwx"),

(: Register restxq modules. Should be done automatically, but there seems to be an occasional bug :)
xrest:register-module(xs:anyURI($target || "/examples/templating/restxq-demo.xql")),
xrest:register-module(xs:anyURI($target || "/examples/contacts/contacts.xql")),
xrest:register-module(xs:anyURI($target || "/examples/xforms/restxq-demo.xql"))