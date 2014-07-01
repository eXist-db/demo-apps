
xquery version "3.0";

(:~
 :  RESTXQ Contacts Demo
 : 
 :  Exposes XQuery functions as resource functions using the RestXQ function annotations.
 : 
 :  About POST and PUT Content-Type: application/exist+json
 :      @discussion: http://comments.gmane.org/gmane.text.xml.exist/44845
 :      Inbound 'application/json' MIME type should be converted to xs:Base64Binary type.
 :      However, my tests show that when 'application/json' MIME type is used, the function parameter is empty.
 :      The workaround is to use a MIME type not present in mime-types.xml database, hence 'application/exist+json'.
 :  
 :  @see Postman API : https://www.getpostman.com/collections/828a57e0250dccc16c88
 : 
 :  @model <contact><id>guid</id><name/><phone/><email/></contact> 
 :
 :  @author Chris Misztur
 :  @version 0.1
 :)

module namespace contacts="http://exist-db.org/apps/demo/restxq/contacts";

import module namespace xqjson="http://xqilla.sourceforge.net/lib/xqjson";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace functx = "http://www.functx.com";

(: where we store the models :)
declare variable $contacts:DATA-STORE as xs:string := '/db/apps/demo/examples/contacts/data/';

(: http codes we return :)
declare variable $contacts:HTTP-OK as xs:integer := 200;
declare variable $contacts:HTTP-CREATED as xs:integer := 200; (: we could use 201 instead :)
declare variable $contacts:HTTP-UPDATED as xs:integer := 200; (: we could use 206 instead. 206 is not used because it does not return a resource :)
declare variable $contacts:HTTP-DELETED as xs:integer := 200; (: we could use 204 instead :)
declare variable $contacts:HTTP-CLIENT-FAIL as xs:integer := 400; (: malformed client request :)
declare variable $contacts:HTTP-NOT-FOUND as xs:integer := 404; (: returned when a resource can not be located :)
declare variable $contacts:HTTP-SERVER-FAIL as xs:integer := 500; (: server side errors :)

(: map client side exception to http code :)
declare variable $contacts:CLIENT-EXCEPTION-MAP := map
    {
        'ResourceNotFound' := $contacts:HTTP-NOT-FOUND,
        'ExternalResourceNotFound' := $contacts:HTTP-NOT-FOUND,
        'InvalidJson' := $contacts:HTTP-CLIENT-FAIL,
        'InvalidModel' := $contacts:HTTP-CLIENT-FAIL,
        'MissingProperty' := $contacts:HTTP-CLIENT-FAIL,
        '*' := $contacts:HTTP-CLIENT-FAIL
    };
    
(: map server side exception to http code :)
declare variable $contacts:SERVER-EXCEPTION-MAP := map
    {
        'DatabaseFail' := $contacts:HTTP-SERVER-FAIL,
        '*' := $contacts:HTTP-SERVER-FAIL
    };
    


(: ******************** :)
(: *** HTTP HELPERS *** :)
(: ******************** :)

(:~ 
 :  Generates a HTTP response element with a payload.  
 :)
declare %private function contacts:http-response($http-code as xs:integer, $resource)
{
    (
        <rest:response>
            <http:response status="{$http-code}">
            </http:response>
        </rest:response>,
        $resource
    )
};

(:~ 
 :  Generates a failed HTTP response element due to a SERVER-SIDE exception.  
 :)
declare %private function contacts:http-response-server-error($error-code, $error-description, $error-value)
{
    contacts:http-response-error
    (
        functx:if-empty($contacts:SERVER-EXCEPTION-MAP($error-code), $contacts:SERVER-EXCEPTION-MAP('*')), 
        $error-code, $error-description, $error-value
    )
};

(:~ 
 :  Generates a failed HTTP response element due to a CLIENT-SIDE exception (malformed request).
 :)
declare %private function contacts:http-response-client-error($error-code, $error-description, $error-value)
{
    contacts:http-response-error
    (
        functx:if-empty($contacts:CLIENT-EXCEPTION-MAP($error-code), $contacts:CLIENT-EXCEPTION-MAP('*')), 
        $error-code, $error-description, $error-value
    )
};

(:~ 
 :  Generates a failed HTTP response element.
 :)
declare %private function contacts:http-response-error($http-code, $error-code, $error-description, $error-value)
{
    (
        <rest:response>
            <http:response status="{$http-code}">
                <http:header name="XQ-Exception" value="{$error-code||':'||$error-description(:||' -- '||$error-value:)}"/>
            </http:response>
        </rest:response>
    )
};


(: ************************** :)
(: *** DATA MANIP HELPERS *** :)
(: ************************** :)
 
(:~ 
 :  Convert a logical range to a sequence-positional range.
 :  Used in resource functions that require paging functionality. 
 :  eg: client side pagination requests 100 records at a time, then the next 100.
 :)
declare %private function contacts:skip-take-range($skip as xs:integer, $take as xs:integer)
{
    map
    {
        'from' := $skip + 1, 
        'to' := $skip + $take
    }
};

(:~ 
 :  Inject an element sequence into the root of another element.
 :)
declare %private function contacts:inject-into($element as element(), $content as element()*)
{
    element { local-name($element) }
    {
        $element/@*,
        $element/child::*,
        $content
    }
};

(:~ 
 :  Wraps an element with <resource></resource> to create a standard response payload type.
 :)
declare %private function contacts:wrap-resource($elements as element()*)
{
    <resource>{$elements}</resource>
};


(: ***************************** :)
(: *** 'HYPER-MEDIA' SUPPORT *** :)
(: ***************************** :)

(:~ 
 :  Resolve 'hyper-links' stored in model.
 :)
declare %private function contacts:resolve-contact-model-links($contact-model as element(contact))
{
    element { 'links' }
    {
        for $link in $contact-model/child::*[@link-type]
        return element { 'a' }
        {
            attribute { 'rel' } { $link/@link-type },
            switch ($link/@link-type) 
            case 'self'
                return
                (
                    attribute { 'href' } { '/exist/restxq/demo/contacts/' || $link/text() },
                    'Self'
                )
            case 'icon'
                return
                (
                    attribute { 'href' } { '/exist/restxq/demo/contacts/images/' || $link/text() },
                    'Image'
                )
            default return ''
        }
    }
};

(:~ 
 :  Strip elements that are resolvable 'hyper-links'.
 :)
declare %private function contacts:strip-contact-model-links($contact-model as element(contact))
{
    element { local-name($contact-model) }
    {
        $contact-model/@*,
        $contact-model/child::*[not(@link-type)]
    }
};

(:~ 
 :  Faux 'hyper-media' pagination for multiple contact retrieval.
 :)
declare %private function contacts:resolve-pagination-links($record-count,$skipped,$taken)
{
    element { 'links' }
    {
        element a { attribute rel { 'prev' }, attribute href { '/exist/restxq/demo/contacts?skip='||$skipped - $taken||'&amp;take='||$taken }, 'Previous' },
        element a { attribute rel { 'self' }, attribute href { '/exist/restxq/demo/contacts?skip='||$skipped||'&amp;take='||$taken }, 'Self' },
        element a { attribute rel { 'next' }, attribute href { '/exist/restxq/demo/contacts?skip='||$skipped + $taken||'&amp;take='||$taken }, 'Next' }
    }
};


(: ********************** :)
(: *** DATA RETR/STOR *** :)
(: ********************** :)

(:~ 
 :  Delete a Contact Model from db.
 :  THROWS DatabaseFail => Failed to delete.
 :  THROWS ResourceNotFound => Resource does not exist.
 :)
declare %private function contacts:delete-contact($id as xs:string)
{
    try
    {
        xmldb:remove($contacts:DATA-STORE, $id||'.xml')
    }
    catch java:org.exist.xquery.XPathException
    {
        error(QName('http://exist-db.org/err', 'ResourceNotFound'), 'Resource not found.')    
    }
    catch *
    {
        error(QName('http://exist-db.org/err', 'DatabaseFail'), 'Database operation failed.')
    }
};

(:~ 
 :  Store a Contact Model in db.
 :  THROWS DatabaseFail => Failed to store.
 :)
declare %private function contacts:store-contact($id as xs:string, $contact-model as element(contact))
{
    let $result := xmldb:store($contacts:DATA-STORE, $id||'.xml',$contact-model)
    
    return if($result)
    then ()
    else (error(QName('http://exist-db.org/err', 'DatabaseFail'), 'Database operation failed.'))
};

(:~ 
 :  Store a image/png in db.
 :  THROWS DatabaseFail => Failed to store.
 :)
declare %private function contacts:store-png($id as xs:string, $image as xs:base64Binary)
{
    let $result := xmldb:store($contacts:DATA-STORE, $id||'.png',$image,'image/png')
    
    return if($result)
    then util:absolute-resource-id($result)
    else (error(QName('http://exist-db.org/err', 'DatabaseFail'), 'Database operation failed.'))
};

(:~ 
 :  Delete a image/png from db.
 :  SILENT FAIL
 :)
declare %private function contacts:delete-png($id as xs:string)
{
    try
    {
        let $remove :=
            xmldb:remove($contacts:DATA-STORE, $id||'.png')
        
        return ()
    }
    catch *
    {
        ()
    }
};

(:~ 
 :  Retrieve a Contact Resource from db by its ID.
 :  THROWS ResourceNotFound => Contact Resource could not be located by ID.
 :)
declare %private function contacts:get-single-contact-by-id($id as xs:string)
{
    let $resource := collection($contacts:DATA-STORE)/contact[id/text() eq $id]
    
    return if($resource)
    then $resource
    else error(QName('http://exist-db.org/err', 'ResourceNotFound'), 'Resource not found.')    
};

(:~ 
 :  Retrieve multiple Contact Resources from db by position.
 :)
declare %private function contacts:get-multiple-contacts-by-position-range($skip as xs:integer, $take as xs:integer)
{
    let $range-map := contacts:skip-take-range($skip,$take)
    (: TODO - introduce a sort order :)
    return for $contact at $position in (collection($contacts:DATA-STORE)/contact)
        [position() = $range-map('from') to $range-map('to')]
    return $contact
};


(: ********************** :)
(: *** XQJSON SUPPORT *** :)
(: ********************** :)

(:~ 
 :  Parses JSON string to XML using XQJSON.
 :  THROWS InvalidJson => XQJSON failed to parse.
 :)
declare %private function contacts:json-to-xml($json as xs:string)
{
    try { xqjson:parse-json($json) }
    catch * { error(QName('http://exist-db.org/err', 'InvalidJson'), 'JSON document is invalid.') }
};

(:~ 
 :  Convert a XQJSON parsed XML node into a simple Contact Model <contact><id/><name/><phone/><email/></contact>
 :)
declare %private function contacts:get-simple-contact-model($xqjson-xml as element(json))
{
    let $contact := $xqjson-xml//.[local-name(.) eq 'pair' and @name eq 'contact']/child::*
    
    return
        <contact>
        {
            for $pair in $contact
            return element { lower-case($pair/@name) } { $pair/text() }
        }
        </contact>
};


(: ******************************* :)
(: *** SIMPLE MODEL VALIDATION *** :)
(: ******************************* :)
 
(:~
 :  Validate a Contact Model.
 :  @param $simple-model - a simple (non-xqjson) Contact Model
 :  @param $required-element-names - sequence of child node names that are required. eg: ('name','phone')
 :  @param $must-have-value - each child node text() must be non-empty
 : 
 :  THROWS InvalidModel => Contact Model is missing a required child element or the element value is empty.
 :)
declare %private function contacts:validate-simple-contact-model($simple-model as element(contact), $required-element-names as xs:string*, $must-have-value as xs:boolean)
{
    let $is-valid :=
        every $element-name in $required-element-names
        satisfies $simple-model/child::*
            [
                local-name(.) eq $element-name and 
                (if($must-have-value) then normalize-space(./text()) else true())
            ]
        
    return if($is-valid)
    then ()
    else error(QName('http://exist-db.org/err', 'InvalidModel'), 'Contact model is invalid.') 
};

(:~
 :  Retrive child element value from a Contact Model.
 :  @param $simple-model - a simple (non-xqjson) Contact Model
 :  @param $element-name - child element name to retrieve value of
 : 
 :  THROWS MissingProperty => Contact Model is missing a required child element.
 :)
declare %private function contacts:get-value-from-contact-model($simple-model as element(contact), $element-name as xs:string)
{
    let $elem := $simple-model/child::*[local-name(.) eq $element-name]
    
    return if($elem)
    then $elem/text()
    else error(QName('http://exist-db.org/err', 'MissingProperty'), 'Property missing from simple model.')
};


(: ************************** :)
(: *** RESOURCE FUNCTIONS *** :)
(: ************************** :)
 
(:~
 :  Retrieve multiple contacts in json format.
 :)
declare
    %rest:GET
    %rest:path("/demo/contacts")
    %rest:query-param("skip", "{$skip}", 0)     (: how many records to skip :)
    %rest:query-param("take", "{$take}", 10)    (: how many records to take :)
    %rest:produces("application/json")
    %output:media-type("application/json")
    %output:method("json")
function contacts:get-multiple($skip as xs:integer*, $take as xs:integer*)
{
    try
    {
        (: get contacts  from data store :)
        let $contacts := 
            contacts:get-multiple-contacts-by-position-range($skip, $take)

        (: wrap them up :)
        let $resource :=
            contacts:wrap-resource
            (
                (
                    for $contact at $position in $contacts
                    return
                    (
                        contacts:strip-contact-model-links
                        (
                            contacts:inject-into
                            (
                                $contact,
                                (<position>{$position}</position>,contacts:resolve-contact-model-links($contact))
                            )
                            
                        )   
                    ),
                    <count>{count($contacts)}</count>,
                    <skip>{$skip}</skip>,
                    <take>{$take}</take>,
                    contacts:resolve-pagination-links(count($contacts),$skip,$take)
                )
            )
          
        (: return to client :)
        return contacts:http-response($contacts:HTTP-OK, $resource)
    }
    catch * 
    {
        contacts:http-response-server-error($err:code,$err:description,$err:value)
    }
};

(:~
 :  Retrieve a single contact in json format.
 :)
declare
    %rest:GET
    %rest:path("/demo/contacts/{$id}")
    %rest:produces("application/json")
    %output:media-type("application/json")
    %output:method("json")
function contacts:get($id as xs:string)
{
    try
    {
        (: get contact from storage by id (THROWS) :)
        let $contacts := 
            contacts:get-single-contact-by-id($id)
          
        (: wrap it up :)  
        let $resource :=
            contacts:wrap-resource
            (
                (
                    contacts:strip-contact-model-links
                    (
                        contacts:inject-into
                        (
                            $contacts,
                            contacts:resolve-contact-model-links($contacts)
                        )
                        
                    ),
                    <count>{count($contacts)}</count>
                )
            )
          
        (: return to client :)
        return contacts:http-response($contacts:HTTP-OK, $resource)
    }
    catch ResourceNotFound
    {
        contacts:http-response-client-error($err:code,$err:description,$err:value)
    }
    catch * 
    {
        contacts:http-response-server-error($err:code,$err:description,$err:value)
    }
};

(:~
 :  Create new contact from json.
 :)
declare
    %rest:POST('{$json-payload}')
    %rest:path("/demo/contacts")
    %rest:consumes("application/exist+json")
    %rest:produces("application/json")
    %output:media-type("application/json")
    %output:method("json")
function contacts:post($json-payload as xs:string)
{
    try
    {
        (: convert json to xml (THROWS) :)
        let $xml-payload := 
            contacts:json-to-xml($json-payload)
        
        (: get a unique id :)
        let $id := 
            util:uuid()
        
        (: let's define the id as a resolvable 'hyper-link' :)
        let $id-link :=
            <id link-type='self'>{$id}</id>
        
        (: get a simple xml model from xqjson format :)
        (: inject the id element into the resource :)
        let $contacts := 
            contacts:inject-into
            (
                contacts:get-simple-contact-model($xml-payload),
                $id-link
            )
        
        (: make sure properties are there and have values (THROWS) :)
        (: we want the client to POST at the very least a name, phone and email :)
        let $validate := 
            contacts:validate-simple-contact-model($contacts, ('id','name','phone','email'), true())
        
        (: store Contact Model in db (THROWS) :)
        let $store :=
            contacts:store-contact($id,$contacts)
        
        (: wrap it up :)
        let $resource :=
            contacts:wrap-resource
            (
                (
                    contacts:strip-contact-model-links
                    (
                        contacts:inject-into
                        (
                            $contacts,
                            contacts:resolve-contact-model-links($contacts)
                        )
                        
                    ),
                    <count>{count($contacts)}</count>
                )
            )
        
        (: send resource back to client :)
        return contacts:http-response($contacts:HTTP-CREATED, $resource)
    }
    catch InvalidJson | InvalidModel
    {
        contacts:http-response-client-error($err:code,$err:description,$err:value)
    }
    catch * | DatabaseFail
    {
        contacts:http-response-server-error($err:code,$err:description,$err:value)
    }
};

(:~
 :  Update a contact from json.
 :)
declare
    %rest:PUT('{$json-payload}')
    %rest:path("/demo/contacts/{$id}")
    %rest:consumes("application/exist+json")
    %rest:produces("application/json")
    %output:media-type("application/json")
    %output:method("json")
function contacts:put($json-payload as xs:string, $id as xs:string)
{
    try
    {
        (: convert json to xml (THROWS) :)
        let $xml-payload := 
            contacts:json-to-xml($json-payload)
        
        (: get existing resource from data store (THROWS) :)
        let $db-contact := 
            contacts:get-single-contact-by-id($id)
        
        (: simplify the xqjson xml :)
        let $contacts := 
            contacts:get-simple-contact-model($xml-payload)
        
        (: update it :)
        let $update :=
        (
            try { update value $db-contact/name with contacts:get-value-from-contact-model($contacts, 'name') } catch MissingProperty { () },
            try { update value $db-contact/phone with contacts:get-value-from-contact-model($contacts, 'phone') } catch MissingProperty { () },
            try { update value $db-contact/email with contacts:get-value-from-contact-model($contacts, 'email') } catch MissingProperty { () }
        )
 
        (: wrap it up :)
        let $resource :=
            contacts:wrap-resource
            (
                (
                    contacts:strip-contact-model-links
                    (
                        contacts:inject-into
                        (
                            $db-contact,
                            contacts:resolve-contact-model-links($db-contact)
                        )
                        
                    ),
                    <count>{count($db-contact)}</count>
                )
            )
        
        (: return it to client :)
        return contacts:http-response($contacts:HTTP-UPDATED, $resource)
    }
    catch InvalidJson | ResourceNotFound
    {
        contacts:http-response-client-error($err:code,$err:description,$err:value)
    }
    catch * 
    {
        contacts:http-response-server-error($err:code,$err:description,$err:value)
    }
};

(:~
 :  Delete a contact by its ID.
 :)
declare
    %rest:DELETE
    %rest:path("/demo/contacts/{$id}")
    %rest:produces("application/json")
    %output:media-type("application/json")
    %output:method("json")
function contacts:delete($id as xs:string)
{
    try
    {
        (: delete it (THROWS) :)
        let $delete :=
            contacts:delete-contact($id)
        
        return contacts:http-response($contacts:HTTP-DELETED, ())
    }
    catch ResourceNotFound
    {
        contacts:http-response-client-error($err:code,$err:description,$err:value)
    }
    catch * | DatabaseFail
    {
        contacts:http-response-server-error($err:code,$err:description,$err:value)
    }
};


(: *************************************** :)
(: *** BINARY IMAGE RESOURCE FUNCTIONS *** :)
(: *************************************** :)
 
(:~ 
 :  Retrieve image from contact by contact's ID.  
 :) 
declare
    %rest:GET
    %rest:path("/demo/contacts/{$id}")
    (:%rest:produces("image/png"):) (: why do I have to leave this out? :)
    %output:media-type("image/png")
    %output:method("binary")
function contacts:get-image($id as xs:string)
{
    try
    {
        (: retrieve the contact model (THROWS) :)
        let $contacts := 
            contacts:get-single-contact-by-id($id)
        
        let $image-bytes := 
            try 
            { 
                util:get-resource-by-absolute-id($contacts/image/text()) 
            } 
            catch * 
            { 
                error(QName('http://exist-db.org/err', 'ResourceNotFound'), 'Resource not found.') 
            }
        
        return contacts:http-response($contacts:HTTP-OK, $image-bytes)
    }
    catch ResourceNotFound
    {
        contacts:http-response-client-error($err:code,$err:description,$err:value)
    }
    catch * | DatabaseFail
    {
        contacts:http-response-server-error($err:code,$err:description,$err:value)
    }
};

(:~ 
 :  Retrieve image from db by image's ID. 
 :) 
declare
    %rest:GET
    %rest:path("/demo/contacts/images/{$resource-id}")
    (:%rest:produces("image/png"):) (: why do I have to leave this out? :)
    %output:media-type("image/png")
    %output:method("binary")
function contacts:get-image-by-resource-id($resource-id as xs:string)
{
    try
    {
        let $image-bytes := 
            try 
            { 
                util:get-resource-by-absolute-id($resource-id) 
            } 
            catch * 
            { 
                error(QName('http://exist-db.org/err', 'ResourceNotFound'), 'Resource not found.') 
            }
        
        return contacts:http-response($contacts:HTTP-OK, $image-bytes)
    }
    catch ResourceNotFound
    {
        contacts:http-response-client-error($err:code,$err:description,$err:value)
    }
    catch * | DatabaseFail
    {
        contacts:http-response-server-error($err:code,$err:description,$err:value)
    }
};
 
(:~ 
 :  Retrieve image from an external source and store it to contact.  
 :) 
declare
    %rest:PUT
    %rest:path("/demo/contacts/{$id}")
    %rest:query-param("uri", "{$uri}", "http://mycatbirdseat.com/wp-content/uploads/2011/10/Putin_guns1.jpg")
    (:%rest:produces("image/png"):)
    %output:media-type("image/png")
    %output:method("binary")
function contacts:put-image-from-uri($id as xs:string, $uri as xs:string*)
{
    try
    {
        (: get the contact (THROWS) :)
        let $contacts :=  
            contacts:get-single-contact-by-id($id)
        
        (: retrieve the image (THROWS):)
        let $image-bytes := 
            (function()
            {
                if($uri) then
                (
                    let $image-response := httpclient:get(xs:anyURI($uri), false(), ())
                    
                    return if
                    (
                        number($image-response/@statusCode) eq $contacts:HTTP-OK and
                        $image-response/httpclient:body/@type eq 'binary'
                    )
                    then xs:base64Binary($image-response/httpclient:body/text())
                    else error(QName('http://exist-db.org/err', 'ExternalResourceNotFound'), 'External resource not found.')
                )
                else error(QName('http://exist-db.org/err', 'ExternalResourceNotFound'), 'External resource not found.')
            }) () 
        
        (: overwrite the image :)
        let $store-img-resource-id :=
        (
            (: TODO - fix journal issue when updating image :)
            contacts:delete-png($id),
            contacts:store-png($id, $image-bytes)
        )
        
        let $link-rel-icon :=
            <image link-type='icon'>{$store-img-resource-id}</image>
        
        let $update-contact :=
            if($contacts/image)
            then
            (
                update replace $contacts/image with $link-rel-icon
            )
            else
            (
                update insert $link-rel-icon into $contacts
            )
        
        return contacts:http-response($contacts:HTTP-UPDATED,$image-bytes)
    }
    catch ResourceNotFound | ExternalResourceNotFound
    {
        contacts:http-response-client-error($err:code,$err:description,$err:value)
    }
    catch * | DatabaseFail
    {
        contacts:http-response-server-error($err:code,$err:description,$err:value)
    }
};
 
 
 
(: TODO - does not work :)
(:~ 
 :  Upload image and store it to contact.
 :) 
(: declare
    %rest:PUT('{$image-payload}')
    %rest:path("/demo/contacts/{$id}")
    %rest:consumes("image/png")
    %rest:produces("image/png")
    %output:media-type("image/png")
    %output:method("binary")
function contacts:put-image-from-body($image-payload as xs:string, $id as xs:string)
{
    try
    {
        contacts:http-response($contacts:HTTP-UPDATED, ())
    }
    catch * 
    {
        contacts:http-response-server-error($err:code,$err:description,$err:value)
    }
}; :)

(:~ 
 :  TEST Retrieve image from an external source and return the httpclient response to client.  
 :) 
declare
    %rest:GET
    %rest:path("/demo/contacts/image-response-test")
    %rest:query-param("uri", "{$uri}", "http://mycatbirdseat.com/wp-content/uploads/2011/10/Putin_guns1.jpg")
    %rest:produces("application/json")
    %output:media-type("application/json")
    %output:method("json")
function contacts:get-image-from-uri-json($uri as xs:string*)
{
    try
    {
        contacts:http-response($contacts:HTTP-OK, <image-response-test>{httpclient:get($uri, false(), ())}</image-response-test>)
    }
    catch * 
    {
        contacts:http-response-server-error($err:code,$err:description,$err:value)
    }
};

(:~ 
 :  TEST Retrieve image from an external source and return the httpclient response to client.  
 :)
declare
    %rest:GET
    %rest:path("/demo/contacts/image-response-test")
    %rest:query-param("uri", "{$uri}", "http://mycatbirdseat.com/wp-content/uploads/2011/10/Putin_guns1.jpg")
    %rest:produces("application/xml")
function contacts:get-image-from-uri-xml($uri as xs:string*)
{
    try
    {
        contacts:http-response($contacts:HTTP-OK, <image-response-test>{httpclient:get($uri, false(), ())}</image-response-test>)
    }
    catch * 
    {
        contacts:http-response-server-error($err:code,$err:description,$err:value)
    }
};

declare function functx:if-empty
  ( $arg as item()? ,
    $value as item()* )  as item()* {

  if (string($arg) != '')
  then data($arg)
  else $value
 } ;