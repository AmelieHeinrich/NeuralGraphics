//
//  TextureCompressor.cpp
//  Pocketcat
//
//  Created by Amélie Heinrich on 02/03/2026.
//

#include "TextureCompressor.h"

#include <Metal/Metal.h>

#define STB_IMAGE_IMPLEMENTATION
#include "ThirdParty/stb_image.h"

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <fstream>

static uint32_t NumMipLevels(uint32_t width, uint32_t height)
{
    return static_cast<uint32_t>(std::floor(std::log2(std::max(width, height)))) + 1;
}

void CompressTexture(const std::string& source, const std::string& out)
{
    // Load source image as RGBA8
    int width, height, channels;
    stbi_uc* pixels = stbi_load(source.c_str(), &width, &height, &channels, 4);
    if (!pixels) {
        fprintf(stderr, "[TextureCompressor] Failed to load: %s\n", source.c_str());
        return;
    }

    uint32_t mipLevels = NumMipLevels(static_cast<uint32_t>(width), static_cast<uint32_t>(height));

    // Create uncompressed source texture (single mip, RGBA8)
    const ATC_Texture* srcTex = nullptr;
    ATC_Error err = ATC_CreateTexture2D(
        nullptr,
        static_cast<uint32_t>(width), static_cast<uint32_t>(height),
        1,
        atcFormatRgba8Unorm,
        atcColorGamutSRGB,
        false,
        &srcTex
    );
    if (err != atcErrorNone) {
        fprintf(stderr, "[TextureCompressor] ATC_CreateTexture2D failed (%d)\n", err);
        stbi_image_free(pixels);
        return;
    }

    ATC_Surface* surface = nullptr;
    ATC_GetSurface(nullptr, srcTex, 0, 0, &surface);
    surface->data     = pixels;
    surface->size     = static_cast<uint32_t>(static_cast<size_t>(width) * height * 4);
    surface->rowBytes = static_cast<uint32_t>(width * 4);

    // Compress to ASTC 6x6, letting ATC generate all mip levels
    ATC_Options options;
    ATC_InitialiseDefaultOptions(&options);
    options.format        = atcFormatAstc6x6Unorm;
    options.quality       = atcQualityProduction;
    options.maxMipmaps    = mipLevels;
    options.mipmapFilter  = atcMipmapFilterBox;
    options.isGammaInSrgb = true;
    options.isGammaOutSrgb = true;
    options.disableMultithreading = true;
    options.disableAnnotation = false;
    options.alphaMode = atcAlphaPreserve;
    options.useAlphaToCoverage = true;

    const ATC_Texture* destTex = nullptr;
    err = ATC_CompressMemory(nullptr, srcTex, &destTex, &options);

    stbi_image_free(pixels);
    ATC_DeleteTexture(nullptr, srcTex, false);

    if (err != atcErrorNone || !destTex) {
        fprintf(stderr, "[TextureCompressor] ATC_CompressMemory failed (%d)\n", err);
        return;
    }

    // Write output: TextureHeader followed by tightly packed mip surfaces
    std::ofstream file(out, std::ios::binary);
    if (!file) {
        fprintf(stderr, "[TextureCompressor] Failed to open output: %s\n", out.c_str());
        ATC_DeleteTexture(nullptr, destTex, true);
        return;
    }

    TextureHeader header = {};
    header.Format    = static_cast<uint32_t>(MTLPixelFormatASTC_6x6_LDR);
    header.Width     = static_cast<uint32_t>(width);
    header.Height    = static_cast<uint32_t>(height);
    header.MipLevels = destTex->numMipLevels;
    file.write(reinterpret_cast<const char*>(&header), sizeof(TextureHeader));

    for (uint32_t mip = 0; mip < destTex->numMipLevels; mip++) {
        ATC_Surface* mipSurface = nullptr;
        ATC_GetSurface(nullptr, destTex, 0, mip, &mipSurface);
        file.write(reinterpret_cast<const char*>(mipSurface->data),
                   static_cast<std::streamsize>(mipSurface->size));
    }

    ATC_DeleteTexture(nullptr, destTex, true);
}
