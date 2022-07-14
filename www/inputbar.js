const exec = require('cordova/exec');
const CDVInputBar = {
    createChatBar:function (success,option){
        exec(success,null,'CDVInputBar','createChatBar',[option]);
    },
    change_textField_placeholder:function (option) {
        exec(null,null,'CDVInputBar','change_textField_placeholder',[option]);
    },
    resetChatBar:function (){
        exec(null,null,'CDVInputBar','resetChatBar',[]);
    },
    closeChatBar:function (){
        exec(null,null,'CDVInputBar','closeChatBar',[]);
    },
    showInputBar:function (success,option){
        exec(success,null,'CDVInputBar','showInputBar',[option]);
    },
    start_voice_record:function (success){
        exec(success,null,'CDVInputBar','start_voice_record',[]);
    },
    stop_voice_record:function (){
        exec(null,null,'CDVInputBar','stop_voice_record',[]);
    }
};
module.exports = CDVInputBar;
