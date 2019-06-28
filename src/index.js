import React, { forwardRef, memo } from 'react'
import {
    View,
    Image,
    NativeModules,
    requireNativeComponent,
    StyleSheet,
    PixelRatio,
    Platform,
} from 'react-native'

const FastImageViewNativeModule = NativeModules.FastImageView

const IS_ANDROID = Platform.OS === 'android';

const IOS_EXTENSION_REG = /\.[a-z]+$/;

function FastImageBase({
    source,
    tintColor,
    onLoadStart,
    onProgress,
    onLoad,
    onError,
    onLoadEnd,
    style,
    children,
    fallback,
    forwardedRef,
    ...props
}) {
    let resolvedSource = null;

    if (IS_ANDROID && source instanceof Object) {
        const styleBorderRadius = (Array.isArray(style) ? StyleSheet.flatten(style) : style).borderRadius || 0;

        if (styleBorderRadius > 0) {
            const borderRadius = Math.round(PixelRatio.getPixelSizeForLayoutSize(styleBorderRadius));
            resolvedSource = Object.assign({}, source, { borderRadius });
        }
    }

    if (resolvedSource === null) {
        resolvedSource = source;
    }

    const containerStyle = [styles.imageContainer, style];

    if (fallback) {
        return (
            <View style={containerStyle} ref={forwardedRef}>
                <Image
                    {...props}
                    tintColor={tintColor}
                    style={StyleSheet.absoluteFill}
                    source={resolvedSource}
                    onLoadStart={onLoadStart}
                    onProgress={onProgress}
                    onLoad={onLoad}
                    onError={onError}
                    onLoadEnd={onLoadEnd}
                />
                {children}
            </View>
        )
    }

    return (
        <View style={containerStyle} ref={forwardedRef}>
            <FastImageView
                {...props}
                tintColor={tintColor}
                style={StyleSheet.absoluteFill}
                source={resolvedSource}
                onFastImageLoadStart={onLoadStart}
                onFastImageProgress={onProgress}
                onFastImageLoad={onLoad}
                onFastImageError={onError}
                onFastImageLoadEnd={onLoadEnd}
            />
            {children}
        </View>
    )
}

const FastImageMemo = memo(FastImageBase)

const FastImage = forwardRef((props, ref) => (
    <FastImageMemo forwardedRef={ref} {...props} />
))

FastImage.displayName = 'FastImage'

const styles = StyleSheet.create({
    imageContainer: {
        overflow: 'hidden',
    },
})

FastImage.resizeMode = {
    contain: 'contain',
    cover: 'cover',
    stretch: 'stretch',
    center: 'center',
}

FastImage.priority = {
    // lower than usual.
    low: 'low',
    // normal, the default.
    normal: 'normal',
    // higher than usual.
    high: 'high',
}

FastImage.cacheControl = {
    // Ignore headers, use uri as cache key, fetch only if not in cache.
    immutable: 'immutable',
    // Respect http headers, no aggressive caching.
    web: 'web',
    // Only load from cache.
    cacheOnly: 'cacheOnly',
}

FastImage.preload = sources => {
    FastImageViewNativeModule.preload(sources)
}

FastImage.defaultProps = {
    resizeMode: FastImage.resizeMode.cover,
}

const FastImageView = requireNativeComponent('FastImageView', FastImage, {
    nativeOnly: {
        onFastImageLoadStart: true,
        onFastImageProgress: true,
        onFastImageLoad: true,
        onFastImageError: true,
        onFastImageLoadEnd: true,
    },
})

export default FastImage
