# Pacote de assets modulares Grid

Origem: release [`Assets-Release`](https://github.com/Botopai50/jogo-3d-godot/releases/tag/Assets-Release)
deste repositório — arquivo `Low.Poly.Modular.Terrain.Pack.zip`
(SHA-256 `a1ea19a8e9d7289ae237d3193cc448537a9025a91344fb3b6a75fd10841fefc2`).

Conteúdo original: **Low Poly Modular Terrain Pack v1.4 (20 Nov 2024)**, distribuído como
`.unitypackage` (pacote da Unity). O `.unitypackage` foi extraído e apenas o subconjunto
efetivamente usado no protótipo foi importado para cá, convertido para o fluxo de importação
do Godot.

## O que foi importado

| Pasta | Conteúdo | Origem no pacote |
| --- | --- | --- |
| `terrain/` | 32 módulos de terreno 100x100 | `Terrain_Assets/Meshes/Terrain/CPT/NoLOD/L` |
| `props/` | 2 montanhas grandes + 3 rochas pequenas | `Terrain_Assets/Meshes/Mountains/CPT/NoLOD` |
| `islets/` | 4 ilhotas para o mar | `Terrain_Assets/Meshes/Islands/CPT/NoLOD` |
| `water/` | 1 plano de água 400x400 | `Terrain_Assets/Meshes/Water` |
| `textures/` | atlas de paleta 64x64 | `Terrain_Assets/Textures` |

As cópias de `Terrain_Texture_Atlas_01.png`, `Terrain_Texture_Atlas_64x64.png` e
`CPT_Terrain_Texture_Atlas_01.png` dentro de `terrain/`, `props/` e `islets/` existem porque
os arquivos `.fbx` referenciam a textura por esse nome, relativo à própria pasta. São o mesmo
atlas de 64x64.

## Licença

O pacote acompanha `License.pdf` com os termos da **Unity Asset Store EULA**. Em resumo, ele
permite usar os assets dentro de um jogo (inclusive comercialmente), mas **proíbe
redistribuir ou repassar os arquivos de asset em si**, mesmo modificados.

Publicar o jogo exportado é uso permitido. Já versionar os arquivos-fonte (`.fbx`, texturas)
em um repositório público, e publicar o pacote completo como release público, é
redistribuição — veja a observação no `README.md`.
