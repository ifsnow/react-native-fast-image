package com.dylanvann.fastimage;

import android.content.Context;
import android.widget.ImageView;

import com.bumptech.glide.load.model.GlideUrl;
import com.bumptech.glide.integration.webp.decoder.WebpDrawable;

class FastImageViewWithUrl extends ImageView {
    public GlideUrl glideUrl;

    private WebpDrawable webpDrawable;

    private boolean hasLoopCount = false;

    private int loopCount = -1;

    public FastImageViewWithUrl(Context context) {
        super(context);
    }

    public void setWebpDrawable(WebpDrawable webpDrawable) {
        this.webpDrawable = webpDrawable;
        this.applyLoopCount();
    }

    public WebpDrawable getWebpDrawable() {
        return this.webpDrawable;
    }

    public void setLoopCount(int loopCount) {
        if (loopCount > -1) {
            this.hasLoopCount = true;
            this.loopCount = loopCount == 0 ? WebpDrawable.LOOP_FOREVER : loopCount;
        }

        this.applyLoopCount();
    }

    private void applyLoopCount() {
        if (this.webpDrawable == null) {
            return;
        }

        if (this.hasLoopCount) {
            this.webpDrawable.setLoopCount(this.loopCount);
        } else {
            this.webpDrawable.setLoopCount(WebpDrawable.LOOP_INTRINSIC);
        }
    }
}
