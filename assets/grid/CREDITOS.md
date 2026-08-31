# Pacote de assets modulares Grid

Origem: release [`Assets-Release`](https://github.com/Botopai50/jogo-3d-godot/releases/tag/Assets-Release)
deste repositório — arquivo `Low.Poly.Modular.Terrain.Pack.zip`
(SHA-256 `a1ea19a8e9d7289ae237d3193cc448537a9025a91344fb3b6a75fd10841fefc2`).

Conteúdo original: **Low Poly Modular Terrain Pack v1.4 (20 Nov 2024)**, distribuído como
`.unitypackage` (pacote da Unity). O `.unitypackage` foi extraído e **o pacote inteiro** foi
importado para cá, convertido para o fluxo de importação do Godot.

## O que foi importado

Todos os **3.263 arquivos `.fbx`** do pacote, na mesma organização de pastas da origem:

| Pasta | Módulos | Origem no pacote |
| --- | ---: | --- |
| `terrain_assets/Terrain/` | 1.460 | módulos de terreno, CPT e MT, em S/M/L, com e sem LOD |
| `terrain_assets/Mountains/` | 960 | montanhas isoladas e rochas |
| `terrain_assets/Islands/` | 400 | ilhas prontas, de S a H |
| `terrain_assets/River/` | 338 | trechos e fins de rio |
| `terrain_assets/Ice/` | 93 | gelo, com e sem fundo |
| `terrain_assets/Water/` | 8 | planos de água e fundo do mar |
| `bonus_assets/Clouds/` | 4 | nuvens |
| `textures/` | 7 | atlas de paleta 64x64 e texturas 16x16 |

Os `.prefab`, `.mat`, `.unity` e `.asset` do pacote **não** foram trazidos: são formatos da
Unity, que o Godot não lê. Eram 3.341 prefabs espelhando as mesmas malhas, além de 20
materiais e 22 cenas de demonstração.

`assets/grid/catalogo.json` indexa os 3.263 módulos com a pegada, a altura mínima e máxima, a
contagem de triângulos e se a peça encaixa na grade — tudo medido a partir da malha importada.

Algumas cópias do atlas aparecem dentro das pastas de malha, com nomes como
`Terrain_Texture_Atlas_01.png` e `Terrain_Texture_Atlas_64x64.png`. Elas existem porque os
`.fbx` referenciam a textura por esse nome, relativo à própria pasta; são o mesmo atlas 64x64.

## O que entra no jogo

O build do navegador leva apenas os **173** módulos de terreno que encaixam na grade de 100
metros, não são cópia de LOD e não afundam abaixo do nível do mar, mais 5 montanhas/rochas e 4
ilhotas. Os 317 MB de `.fbx` de origem ficam fora do export; o acervo completo existe no
repositório para uso futuro.

## Licença

O pacote acompanha `License.pdf` com os termos da **Unity Asset Store EULA**. Em resumo, ele
permite usar os assets dentro de um jogo (inclusive comercialmente), mas **proíbe
redistribuir ou repassar os arquivos de asset em si**, mesmo modificados.

Publicar o jogo exportado é uso permitido. Já versionar os arquivos-fonte (`.fbx`, texturas)
em um repositório público, e publicar o pacote completo como release público, é
redistribuição — veja a observação no `README.md`.
