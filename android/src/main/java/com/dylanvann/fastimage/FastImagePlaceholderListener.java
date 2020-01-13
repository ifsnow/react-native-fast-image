package com.dylanvann.fastimage;

import android.graphics.drawable.AnimationDrawable;
import android.graphics.drawable.Drawable;

import com.bumptech.glide.load.DataSource;
import com.bumptech.glide.load.engine.GlideException;
import com.bumptech.glide.request.RequestListener;
import com.bumptech.glide.request.target.Target;

public class FastImagePlaceholderListener implements RequestListener<Drawable> {
    AnimationDrawable anim;

    FastImagePlaceholderListener(AnimationDrawable anim) {
        this.anim = anim;
    }

    @Override
    public boolean onLoadFailed(@androidx.annotation.Nullable GlideException e, Object model, Target<Drawable> target, boolean isFirstResource) {
        if (this.anim.isRunning()) {
            this.anim.stop();
        }
        return false;
    }

    @Override
    public boolean onResourceReady(Drawable resource, Object model, Target<Drawable> target, DataSource dataSource, boolean isFirstResource) {
        if (this.anim.isRunning()) {
            this.anim.stop();
        }
        return false;
    }
}
