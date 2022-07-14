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
    recordAudio:function (success,option){
        exec(success,null,'CDVInputBar','recordAudio',[option]);
    }
};
module.exports = CDVInputBar;
