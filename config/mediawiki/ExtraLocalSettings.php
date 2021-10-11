<?php
# Protect against web entry
if ( !defined( 'MEDIAWIKI' ) ) {
    exit;
}

# need to be to an IP that is used to externally reach the container. if 127.0.0.1 is used, it will resolve internally and will not work
#$wgServer = "http://192.168.2.116:8080";

$wgSMTP = [                                                                             
    'host' => 'ssl://smtp.gmail.com', // hostname of the email server                   
    'IDHost' => 'gmail.com',                                                            
    'port' => 465,                                                                      
    'username' => 'user@domain.com', // user of the email account                        
    'password' => 'somepass', // app password of the email account                       
    'auth' => true                                                                      
];                                                                                      
                                                                                        
$wgSessionCacheType = CACHE_DB;                                                         
$wgCookieSecure = false;                                                                
                                                                                        
$GLOBALS['wgNamespacesWithSubpages'][NS_MAIN] = 1;                                      
$GLOBALS['egSPLAutorefresh'] = true;                                                    
                 
$wgDefaultSkin = 'timeless';
# $wgDefaultSkin = 'minerva'; # if minerva fixes the bugs of no edit action on the main page and no suggestions to create page on no search results, then uncomment this and comment the next line
$wgMFDefaultSkinClass = 'SkinMinerva'; 

#$wgDebugLogFile = "/var/log/mediawiki/debug-{$wgDBname}.log";                                                                                                                
#$wgShowExceptionDetails = true;
#$wgMainCacheType = CACHE_NONE;
#$wgShowSQLErrors = true;
#$wgShowDBErrorBacktrace = true;
#$wgDebugToolbar = true;
#use MWDebug;
#MWDebug::init();



