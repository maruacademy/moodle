<?php  // Moodle configuration file

unset($CFG);
global $CFG;
$CFG = new stdClass();

$CFG->dbtype    = 'auroramysql';
$CFG->dblibrary = 'native';
$CFG->dbhost    = getenv('MOODLE_DB_HOST');
$CFG->dbname    = getenv('MOODLE_DB_NAME') ?: 'moodle';
$CFG->dbuser    = getenv('MOODLE_DB_USER');
$CFG->dbpass    = getenv('MOODLE_DB_PASS');
$CFG->prefix    = 'mdl_';
$CFG->dboptions = array (
  'dbpersist' => 0,
  'dbport' => '',
  'dbsocket' => '',
  'dbcollation' => 'utf8mb4_unicode_ci',
);

$CFG->wwwroot       = getenv('MOODLE_WWWROOT') ?: 'https://learn.maruacademy.com.au';
$CFG->sslproxy      = true;
$CFG->dataroot      = '/mnt/moodledata';
$CFG->admin         = 'admin';
$CFG->routerconfigured = true;
$CFG->directorypermissions = 02775;
$CFG->filepermissions      = 00644;

$CFG->noemailever = false;
$CFG->localcachedir = '/tmp/moodle-localcache';
$CFG->preventexecpath = true;

// REDIS SESSION HANDLING (ElastiCache TLS)
$CFG->session_handler_class = '\core\session\redis';
$CFG->session_redis_host = getenv('MOODLE_REDIS_HOST');
$CFG->session_redis_port = 6379;
$CFG->session_redis_encrypt = [
    'ssl' => [
        'verify_peer'      => false,
        'verify_peer_name' => false,
    ]
];

$CFG->session_redis_auth = getenv('MOODLE_REDIS_AUTH') ?: '';
$CFG->session_redis_prefix = 'mdl_sess_';
$CFG->session_redis_acquire_lock_timeout = 120;
$CFG->session_redis_lock_expire = 7200;

require_once(__DIR__ . '/lib/setup.php');
