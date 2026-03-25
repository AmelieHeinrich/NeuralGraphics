# Pocketcat

![](.github/reg.png)
![](.github/pt.png)
![](.github/pt2.png)

This repository showcases various modern rendering techniques implemented using Metal 4 API, focused on GPU driven rendering, raytracing and neural graphics.

## Building and running

This project works on any M3+ GPU. Anything below is not supported due to lack of support for indirect mesh ICB and Metal 4 raytracing.\
To build, just open the project in Xcode and run the Pocketcat scheme.\
The project provides 3 baked meshes by default: cube, cube+sphere, and Crytek Sponza. To add more meshes, you can add any GLTF model in SourceAssets and run the AssetBaker program to bake everything. The engine does not support runtime creation of scenes, you have to declare them programmatically in Pocketcat/Core/Scene.swift.

## Current features

- Raytraced sun shadows
- Mesh shaders
- GPU driven debug renderer
- GPU driven TLAS build
- Visibility buffer
- MetalFX spatial/temporal upscaling
- Stochastic reference pathtracer

## Work in progress

- SVGF
- RTGI
- RTAO
- Nanite

## TODO

- Inference engine
- NNAO
