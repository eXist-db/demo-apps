/*
 * jQuery scrollExtend plugin v1.0.1
 * 
 * Copyright (c) 2009 Jim Keller
 * Context - http://www.contextllc.com
 * 
 * Dual licensed under the MIT and GPL licenses.
 *
 */

jQuery.fn.onScrollBeyond=function(callback,options){var domTargetElement=this;if(callback=='disable'){jQuery(domTargetElement).data('onScrollBeyond-disabled',true);return;}
if(callback=='enable'){jQuery(domTargetElement).data('onScrollBeyond-disabled',false);return;}
var settings={'buffer':20,'fireOnDocEnd':true,'fireOnBeyondElement':true};jQuery.extend(settings,options);jQuery(window).bind('scroll',function(){var fire=false;var jqTargetElement=jQuery(domTargetElement);if(jqTargetElement.data('onScrollBeyond-disabled')==true){return;}
if(settings.fireOnBeyondElement){if(jQuery(document).scrollTop()>(jqTargetElement.position().top+jqTargetElement.height())){fire=true;}}
if(!fire&&settings.fireOnDocEnd){var amt_scrolled=jQuery(document).scrollTop()-jqTargetElement.position().top;if((amt_scrolled+jqTargetElement.position().top+jQuery(window).height()+settings.buffer)>jQuery(document).height()){fire=true;}}
if(fire){callback.call(this,domTargetElement);}});return this;};jQuery.fn.scrollExtend=function(options){if(options=='disable'){jQuery(this).data('scrollExtend-disabled',true);return;}
if(options=='enable'){jQuery(this).data('scrollExtend-disabled',false);return;}
var settings={'url':null,'beforeStart':null,'onSuccess':null,'target':null,'loadingIndicatorEnabled':true,'loadingIndicatorClass':'scrollExtend-loading','newElementClass':'','ajaxSettings':{}};var url;var localAjaxSettings={};var ajaxSettings=settings.ajaxSettings;jQuery.extend(settings,options);jQuery.extend(ajaxSettings,settings.ajaxSettings);jQuery(this).onScrollBeyond(function(container){var jqContainerElem=jQuery(container);if(jqContainerElem.data('scrollExtend-disabled')!=true&&jqContainerElem.data('scrollExtendLoading')!=true){jqContainerElem.data('scrollExtendLoading',true);if(typeof(settings.beforeStart)=='function'){var ret=settings.beforeStart.call(this,container);if(!ret){jqContainerElem.data('scrollExtendLoading',false);return;}}
if(jqContainerElem.data('scrollExtend-disabled')==true){jqContainerElem.data('scrollExtendLoading',false);return;}
if(typeof(settings.url)=='function'){url=settings.url.call(this,container);}
else{url=settings.url;}
ajaxSettings.url=url;var target=(settings.target)?settings.target:container;var new_elem=(container.is('table'))?jQuery('<tbody/>'):jQuery('<div/>');if(settings.newElementClass!=''){jQuery(new_elem).addClass(settings.newElementClass);}
if(settings.loadingIndicatorEnabled){var jqLoadingElem=jQuery('<div></div>');jqLoadingElem.addClass(settings.loadingIndicatorClass);jqLoadingElem.appendTo(target);}
localAjaxSettings={'success':function(data,textStatus){var target=(settings.target)?settings.target:container;jQuery(new_elem).html(data);jQuery(new_elem).appendTo(target);if(typeof(settings.onSuccess)=='function'){settings.onSuccess.call(this,container,new_elem);}
jQuery(container).data('scrollExtendLoading',false);if(settings.loadingIndicatorEnabled){jqLoadingElem.remove();}}}
jQuery.extend(ajaxSettings,localAjaxSettings);jQuery.ajax(ajaxSettings);}},settings);return this;};