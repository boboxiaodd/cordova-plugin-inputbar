const exec = require('cordova/exec');
const CDVInputBar = {
    create_chatbar:function (success,fail,option){
        exec(success,fail,'CDVInputBar','create_chatbar',[option]);
    }
};
module.exports = CDVInputBar;
