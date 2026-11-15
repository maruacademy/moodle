<?php  // Moodle configuration file

unset($CFG);
global $CFG;
$CFG = new stdClass();

$CFG->dbtype    = 'auroramysql';
$CFG->dblibrary = 'native';
$CFG->dbhost    = 'maru-moodle-db.cluster-crkc8w28olh1.ap-southeast-2.rds.amazonaws.com';
$CFG->dbname    = 'moodle';
$CFG->dbuser    = 'moodleapp';
$CFG->dbpass    = 'MARUxxxx2026@';
$CFG->prefix    = 'mdl_';
$CFG->dboptions = array (
  'dbpersist' => 0,
  'dbport' => '',
  'dbsocket' => '',
  'dbcollation' => 'utf8mb4_unicode_ci',
);

// $CFG->wwwroot    = 'http://marumoodle-prod-v2.eba-fw7dypck.ap-southeast-2.elasticbeanstalk.com';
$CFG->wwwroot       = 'https://learn.maruacademy.com.au';
$CFG->sslproxy      = true;
// $CFG->reverseproxy   = true;
$CFG->dataroot      = '/mnt/moodledata';
$CFG->admin         = 'admin';
// $CFG->siteadmins = 'admin_erwin,admin_michael,admin_karen';
$CFG->routerconfigured = true;
$CFG->directorypermissions = 02775;
$CFG->filepermissions      = 00644;

// Tell Moodle to pull the true IP directly from Cloudflare's isolated header
// $CFG->getremoteaddrconf = 'HTTP_CF_CONNECTING_IP';

// Disable email server
$CFG->noemailever = false;

// REQUIRED: Auto Scaling Overrides for Cache & Sessions
$CFG->localcachedir = '/tmp/moodle-localcache';
// $CFG->dbsessions = 1; Removed since we're using REDIS

// Prevent executable paths
$CFG->preventexecpath = true;

// REDIS SESSION HANDLING (ElastiCache TLS)
$CFG->session_handler_class = '\core\session\redis';
$CFG->session_redis_host = 'master.marumoodle-redis-tls.trutt8.apse2.cache.amazonaws.com';
$CFG->session_redis_port = 6379;
$CFG->session_redis_encrypt = [
    'ssl' => [
        'verify_peer'      => false,
        'verify_peer_name' => false,
    ]
];

$CFG->session_redis_auth = '';
$CFG->session_redis_prefix = 'mdl_sess_';
$CFG->session_redis_acquire_lock_timeout = 120;
$CFG->session_redis_lock_expire = 7200;

// $CFG->debug = (E_ALL | E_STRICT);
// $CFG->debugdisplay = 1;

require_once(__DIR__ . '/lib/setup.php');

// There is no php closing tag in this file,
// it is intentional because it prevents trailing whitespace problems!
