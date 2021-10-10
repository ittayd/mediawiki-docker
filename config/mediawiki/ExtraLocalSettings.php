<?php
# Protect against web entry
if ( !defined( 'MEDIAWIKI' ) ) {
    exit;
}

$wgSMTP = [                                                                             
    'host' => 'ssl://smtp.gmail.com', // hostname of the email server                   
    'IDHost' => 'gmail.com',                                                            
    'port' => 465,                                                                      
    'username' => '', // user of the email account                        
    'password' => '', // app password of the email account                       
    'auth' => true                                                                      
];                                                                                      
                                                                                        
#$wgDebugLogFile = "/var/log/mediawiki/debug-{$wgDBname}.log";                          
                                                                                        
$wgSessionCacheType = CACHE_DB;                                                         
$wgCookieSecure = false;                                                                
                                                                                        
$GLOBALS['wgNamespacesWithSubpages'][NS_MAIN] = 1;                                      
$GLOBALS['egSPLAutorefresh'] = true;                                                    
                                                                                        
wfLoadSkin( 'MinervaNeue' );                                                            
$wgDefaultSkin = 'minerva';                                                             
wfLoadExtension( 'MobileFrontend' );                                                    
$wgMFDefaultSkinClass = 'SkinMinerva';                                                  