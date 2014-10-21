var contactsApp = angular.module('contactsApp', ['ngRoute','ngAnimate','angularSpinner']);


var showAjaxError = function(headers) {
    if(headers('XQ-Exception') === null) 
    { alert("Service Unavailable!"); } 
    else 
    { alert(headers('XQ-Exception')); }
}
            
var getLinkByRel = function(links, rel) {
    if(links.a instanceof Array) { // check if Array first
        return links.a.filter(function( link ) {
          return link.rel == rel;
        })[0]; // since links should be unique, we only care about the first one
    } else if(links.a instanceof Object && links.a.rel == rel) {
        return links.a;
    } else {
        return undefined;
    }
}

var makeArray = function(obj) {
    if(obj instanceof Array) {
        return obj;
    } else if(obj instanceof Object) {
        return [].concat(obj)
    } else {
        return undefined;
    }
}

contactsApp.controller('newContact',
    function($scope, $http, $location, usSpinnerService)
    {
        $scope.cancel = function ()
        {
            $location
                .search('uri',null)
                .path("/browseContacts");
        }
        
        $scope.create = function (contact)
        {
            if(contact.$valid)
            {
                usSpinnerService.spin('spinner-1');
                
                var onSuccess = function(result) {
                    usSpinnerService.stop('spinner-1');
                    $scope.cancel();
                }
    
                var onFailure = function(result) {
                    usSpinnerService.stop('spinner-1');
                    showAjaxError(result.headers);
                }
                    
                $http
                    .defaults
                    .headers
                    .post['Content-Type'] = 'application/exist+json'; //TODO: fix this non-standard content type
                
                $http
                    .post('/exist/restxq/demo/contacts',
                    { 
                        "contact" :
                        {
                            "name" : contact.name,
                            "phone" : contact.phone,
                            "email" : contact.email
                        }
                    })
                    .then(onSuccess, onFailure);
            }
        }
    });


contactsApp.controller('updateContact',
    function($scope, $http, $location, $q, usSpinnerService)
    {
        $scope.getContactIconRel = function(contact)
        {
            return ( contact === undefined || getLinkByRel(contact.links,'icon') === undefined ) ? 
                        'http://placekitten.com/240/240' : 
                        getLinkByRel(contact.links,'icon').href;
        }
        
        $scope.$on('$routeChangeSuccess', function (event, currentRoute, previousRoute) 
        { 
            usSpinnerService.spin('spinner-1');
            
            var onSuccess = function(result) {
                usSpinnerService.stop('spinner-1');
                $scope.contact = result.data.contact;
            }

            var onFailure = function(result) {
                usSpinnerService.stop('spinner-1');
                showAjaxError(result.headers);
            }
                
            $http
                .get($location.search().uri)
                .then(onSuccess, onFailure);
        });
        
        $scope.cancel = function ()
        {
            $location
                .search('uri',null)
                .path("/browseContacts");
        }
        
        $scope.update = function (contact)
        {
            //if(contact.$valid)    //TODO: not sure the difference between $scope.contact and contact at this point
            {
                usSpinnerService.spin('spinner-1');
                
                var onSuccess = function(result) {
                    usSpinnerService.stop('spinner-1');
                    $scope.cancel();
                }
    
                var onFailure = function(result) {
                    usSpinnerService.stop('spinner-1');
                    showAjaxError(result.headers);
                }
                    
                $http
                    .defaults
                    .headers
                    .put['Content-Type'] = 'application/exist+json'; //TODO: fix this non-standard content type
                
                $q
                    .all([
                        $http
                            .put($location.search().uri,
                            { 
                                "contact" :
                                {
                                    "name" : contact.name,
                                    "phone" : contact.phone,
                                    "email" : contact.email
                                }
                            }),
                        (contact.image === undefined) ?
                            function() {} :
                            $http
                                .put($location.search().uri + '?uri=' + contact.image)
                        ])
                    .then(onSuccess, onFailure);
            }
        }
    });

contactsApp.controller('browseContacts',
    function($scope, $http, $location, usSpinnerService)
    {
        $scope.uri = function () {
            return ( $location.search().uri === undefined ) ?
                '/exist/restxq/demo/contacts?skip=0&take=5' :
                $location.search().uri;
        }
        
        $scope.getContactIconRel = function(contact)
        {
            return ( getLinkByRel(contact.links,'icon') === undefined ) ? 
                        'http://placekitten.com/g/59/59' : 
                        getLinkByRel(contact.links,'icon').href;
        }
        
        $scope.$on('$routeChangeSuccess', function (event, currentRoute, previousRoute) 
        { 
            usSpinnerService.spin('spinner-1');
            
            var onSuccess = function(result) {
                usSpinnerService.stop('spinner-1');

                $scope.contacts = makeArray(result.data.contact);
                
                //console.log(result.data);
                //console.log($scope.contacts);

                $scope.previousPage = function() {
                    $location.search('uri', getLinkByRel(result.data.links,'prev').href).path('/browseContacts');
                }
                
                $scope.refreshPage = function() {
                    $location.search('uri', getLinkByRel(result.data.links,'self').href).path('/browseContacts');
                }
                
                $scope.nextPage = function() {
                    $location.search('uri', getLinkByRel(result.data.links,'next').href).path('/browseContacts');
                }
            }

            var onFailure = function(result) {
                usSpinnerService.stop('spinner-1');
                showAjaxError(result.headers);
            }
                
            $http
                .get($scope.uri())
                .then(onSuccess, onFailure);
        });
        
        $scope.new = function() {
            $location
                .search('uri',null)
                .path("/newContact");
        }
        
        $scope.delete = function(contact) {
            usSpinnerService.spin('spinner-1');
                
            var onSuccess = function(result) {
                usSpinnerService.stop('spinner-1');
                $scope.refreshPage();
            }

            var onFailure = function(result) {
                usSpinnerService.stop('spinner-1');
                showAjaxError(result.headers);
            }
                
            $http
                .delete(getLinkByRel(contact.links,'self').href)
                .then(onSuccess, onFailure);
        }
        
        $scope.update = function(contact) {
            $location
               .search('uri',getLinkByRel(contact.links,'self').href)
               .path("/updateContact");
        }
    });


contactsApp.config(function ($routeProvider) {
    $routeProvider
        .when('/newContact',
            {
                controller: 'newContact',
                templateUrl: 'newContact.html'
            })
        .when('/updateContact',
            {
                controller: 'updateContact',
                templateUrl: 'updateContact.html'
            })
        .when('/browseContacts',
            {
                controller: 'browseContacts',
                templateUrl: 'browseContacts.html'
            })
        .otherwise({ redirectTo: '/browseContacts'});
    });