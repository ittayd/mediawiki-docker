<?php
# Protect against web entry
if ( !defined( 'MEDIAWIKI' ) ) {
    exit;
}

$ini = parse_ini_file("ExtraLocalConfig.ini");
if ($ini['smtp_user'] == 'foo@bar.com') {
    throw new Exception('ExtraLocalConfig.ini has default values');
}

# need to be to an IP that is used to externally reach the container. if 127.0.0.1 is used, it will resolve internally and will not work
#$wgServer = "http://192.168.2.116:8080";

$wgEmergencyContact = $ini['smtp_user'];
$wgPasswordSender = $ini['smtp_user'];

$wgSMTP = [                                                                             
    'host' => 'ssl://smtp.gmail.com', // hostname of the email server                   
    'IDHost' => 'gmail.com',                                                            
    'port' => 465,                                                                      
    'username' => $ini['smtp_user'], // user of the email account                        
    'password' => $ini['smtp_pass'], // app password of the email account                       
    'auth' => true                                                                      
];                                                                                      
                                                                                        
$wgSessionCacheType = CACHE_DB;                                                         
$wgCookieSecure = false;                                                                
                                                                                        
$GLOBALS['wgNamespacesWithSubpages'][NS_MAIN] = 1;                                      
$GLOBALS['egSPLAutorefresh'] = true;                                                    
                 
$wgDefaultSkin = 'timeless';
# $wgDefaultSkin = 'minerva'; # if minerva fixes the bugs of no edit action on the main page and no suggestions to create page on no search results, then uncomment this and comment the next line
$wgMFDefaultSkinClass = 'SkinMinerva'; 
$wgMFAutodetectMobileView = true;

$wgCacheDirectory = "$IP/cache";

#$wgDebugLogFile = "/var/log/mediawiki/debug-{$wgDBname}.log";                                                                                                                
#$wgShowExceptionDetails = true;
#$wgMainCacheType = CACHE_NONE;
#$wgShowSQLErrors = true;
#$wgShowDBErrorBacktrace = true;
#$wgDebugToolbar = true;
#use MWDebug;
#MWDebug::init();



