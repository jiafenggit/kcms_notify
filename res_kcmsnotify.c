/*
*  (c) copyleft 2013 Konstantin Artemiev
*  Simple gateway of AMI events via libzmq socket protocol
*
*/

#include "asterisk.h"

ASTERISK_FILE_VERSION(__FILE__, "$Revision: $")

#include "asterisk/module.h"
#include "asterisk/logger.h"
#include "asterisk/cli.h"
#include "asterisk/manager.h"
#include "asterisk/config.h"
#include "asterisk/config_options.h"
#include "zmq.h"

#define DEFAULT_URI		"tcp://127.0.0.1:5555"
#define MODULENAME 		"KCMS Notify"
#define CONNECTED_MSG 		"%s is loaded"
#define DISCONNECTED_MSG 	"unloaded"

/*** MODULEINFO
        <depend>ZMQ</depend>
 ***/

static void *context;
static void *sock;
static char global_uri[64];

static int load_configuration(int reload)
{
    struct ast_config *cfg;
    char *cat = NULL;
    struct ast_variable *var;

  struct ast_flags config_flags = { reload ? CONFIG_FLAG_FILEUNCHANGED : 0 };
    int res = 0;
    cfg = ast_config_load("res_kcmsnotify.conf", config_flags);
    if (!cfg) {
        ast_log(AST_LOG_WARNING, "Config file res_kcmsnotify.conf failed to load\n");
        return 1;
    } else if (cfg == CONFIG_STATUS_FILEINVALID) {
        ast_log(AST_LOG_WARNING, "Config file res_kcmsnotify.conf is invalid\n");
        return 1;
    } else if (cfg == CONFIG_STATUS_FILEUNCHANGED) {
        return 0;
    }
    strncpy(global_uri, DEFAULT_URI,strlen(DEFAULT_URI));
    while ((cat = ast_category_browse(cfg, cat))) {

        if (strcasecmp(cat, "general")) {
            continue;
        }

        var = ast_variable_browse(cfg, cat);
        while (var) {
            if (!strcasecmp(var->name, "uri")) {
                ast_copy_string(global_uri, var->value, sizeof(global_uri));
            } else {
                ast_log(AST_LOG_WARNING, "Unknown configuration key %s\n", var->name);
            }
            var = var->next;
        }
    }
 
cleanup:
    ast_config_destroy(cfg);
    return res;
}


static void log_module_values(void)
{
    ast_verb(0,"AMI Events pushing URI: %s\n",
        global_uri);
}

static int amihook_helper(int category, const char *event, char *content)
{
    size_t len;
    zmq_msg_t msg1;
    len = strlen(content) + 1; 
    zmq_msg_init_size(&msg1, len);
    zmq_pollitem_t items [1];
    items[0].socket = socket;
    items[0].events = ZMQ_POLLOUT;
    int rc = zmq_poll (items, 1, -1);
    memcpy(zmq_msg_data(&msg1), content, len);
    zmq_msg_send(&msg1, sock, ZMQ_DONTWAIT);
    zmq_msg_close(&msg1);
    return 0;
}

static struct manager_custom_hook test_hook = {
        .file = __FILE__,
        .helper = &amihook_helper,
};

static int reload_module(void)
{
    if (load_configuration(1)) {
        return AST_MODULE_LOAD_DECLINE;
    }
    return AST_MODULE_LOAD_SUCCESS;
}

static int load_module(void)
{
   if (load_configuration(0)) {
        return AST_MODULE_LOAD_DECLINE;
    }
    ast_verb(0,CONNECTED_MSG,MODULENAME);
    log_module_values();
    context = zmq_ctx_new();
    sock = zmq_socket(context, ZMQ_PUSH);
    zmq_connect(sock, global_uri);
    ast_manager_unregister_hook(&test_hook);
    ast_manager_register_hook(&test_hook);
    return AST_MODULE_LOAD_SUCCESS;
}


static int unload_module(void) {
    zmq_disconnect(sock, global_uri);
    zmq_ctx_destroy(context);
    ast_verb(0,DISCONNECTED_MSG);
    return 0;
}


AST_MODULE_INFO(ASTERISK_GPL_KEY, AST_MODFLAG_LOAD_ORDER, "KCMS Notify",
    .load = load_module,
    .unload = unload_module,
    .reload = reload_module,
);

