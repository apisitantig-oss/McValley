package mcvalley;

import cpw.mods.fml.client.FMLClientHandler;
import cpw.mods.fml.common.eventhandler.EventPriority;
import cpw.mods.fml.common.eventhandler.SubscribeEvent;
import net.minecraft.client.Minecraft;
import net.minecraft.client.entity.EntityClientPlayerMP;
import net.minecraft.client.gui.Gui;
import net.minecraft.client.gui.ScaledResolution;
import net.minecraft.util.ResourceLocation;
import net.minecraftforge.client.event.RenderGameOverlayEvent;

public class lockmod extends Gui {
    private static final ResourceLocation closegui = new ResourceLocation("mcvalley:textures/gui/lockgui.png");

    public lockmod(Minecraft mc) {
        // Keep constructor for compatibility with client.java
    }

    @SubscribeEvent(priority=EventPriority.NORMAL)
    public void onRenderExperienceBar(RenderGameOverlayEvent.Post event) {
        if (event.type != RenderGameOverlayEvent.ElementType.HOTBAR) {
            return;
        }
        Minecraft mc = Minecraft.getMinecraft();
        if (mc == null) {
            return;
        }
        ScaledResolution scaledresolution = new ScaledResolution(mc, mc.displayWidth, mc.displayHeight);
        String serverIP = "";
        if (!mc.isSingleplayer()) {
            if (mc.func_147104_D() != null && mc.func_147104_D().serverIP != null) {
                serverIP = mc.func_147104_D().serverIP.toLowerCase();
                if (!serverIP.trim().equalsIgnoreCase("hitza13.thddns.net:5570")) {
                    mc.getTextureManager().bindTexture(closegui);
                    this.drawTexturedModalRect(0, 0, 0, 0, 1000, 1000);
                    if (mc.thePlayer != null && mc.thePlayer.ticksExisted % 300 == 1) {
                        mc.shutdown();
                    }
                }
            }
        }
    }
}
