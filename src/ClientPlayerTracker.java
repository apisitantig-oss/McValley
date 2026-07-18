package net.gliby.voicechat.client.networking.game;

import cpw.mods.fml.common.eventhandler.SubscribeEvent;
import cpw.mods.fml.common.network.FMLNetworkEvent;
import net.gliby.voicechat.client.VoiceChatClient;

public class ClientPlayerTracker {
    VoiceChatClient voiceChat;

    public ClientPlayerTracker(VoiceChatClient voiceChatClient) {
        this.voiceChat = voiceChatClient;
    }

    @SubscribeEvent
    public void onPlayerLogout(FMLNetworkEvent.ClientDisconnectionFromServerEvent event) {
        if (this.voiceChat.getSoundManager() != null) {
            this.voiceChat.getSoundManager().reset();
        }
    }
}
