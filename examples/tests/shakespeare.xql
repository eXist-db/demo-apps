xquery version "1.0";

import module namespace test="http://exist-db.org/xquery/xqsuite" at "resource:org/exist/xquery/lib/xqsuite/xqsuite.xql";
import module namespace t="http://exist-db.org/apps/demo/shakespeare/tests" at "shakespeare-tests.xql";

test:suite(util:list-functions("http://exist-db.org/apps/demo/shakespeare/tests"))

(:util:inspect-function(shakes:create-query#2):)