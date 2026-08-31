# Jogo 3D Godot

Protótipo de um **jogo 3D em primeira pessoa** feito na **Godot Engine 4.7.2 (stable)**:
uma ilha grande cercada pelo mar, montada com os assets modulares **Grid**, para andar,
correr e pular no navegador.

**Jogar:** https://botopai50.github.io/jogo-3d-godot/

## Controles

| Tecla | Ação |
| --- | --- |
| `W` `A` `S` `D` (ou as setas) | Andar |
| `Shift` (segurando) | Correr |
| `Espaço` | Pular (só com os pés no chão) |
| Mouse | Olhar |
| Clique | Capturar o mouse |
| `Esc` | Liberar o mouse |

No navegador o travamento do ponteiro depende de um gesto do usuário, então é preciso
clicar na tela uma vez para começar a jogar.

## O que existe no protótipo

- Personagem em primeira pessoa (`CharacterBody3D` com cápsula de colisão), com velocidades
  de caminhada e corrida ajustáveis separadamente, aceleração, desaceleração, gravidade
  própria e pulo permitido apenas quando está no chão.
- Câmera controlada pelo mouse: o giro horizontal roda o corpo, o vertical roda só a câmera,
  com a inclinação presa entre -89° e +89°.
- Ilha de aproximadamente 1,3 km de ponta a ponta, com costa orgânica contínua e um miolo
  modular de 100x100 metros: grandes planícies, colinas esparsas e uma cadeia montanhosa
  curta com alturas variadas.
- Mar em volta, ilhotas ao largo, montanhas isoladas, afloramentos e pedras espalhadas como
  pontos de referência, e nuvens no céu — tudo sorteado do acervo do pacote.
- Colisão em todo o terreno e paredes invisíveis na linha de costa, para o personagem não
  cair para fora do cenário.

Não há combate, inventário, coleta, inimigos, missões, diálogos nem interação com objetos:
o protótipo é só o que está na lista acima.

## Requisitos

- [Godot Engine 4.7.2 stable](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable)
  (versão padrão, sem .NET)

A linha 4.8 ainda está em desenvolvimento (só existem snapshots `4.8-dev*`, que a própria
equipe do Godot marca como inadequados para produção), por isso a base é a 4.7.2.

## Como abrir o projeto

1. Clone o repositório.
2. Abra o Godot 4.7.2 e clique em **Import**.
3. Selecione o `project.godot` na raiz.

O renderizador é o **Compatibility (OpenGL)**, que é o modo compatível com export para
navegador.

## Estrutura de pastas

```
.
├── assets/grid/          # Pacote Grid inteiro: 3.263 módulos
│   ├── terrain_assets/   #   Terrain, Mountains, Islands, River, Ice, Water
│   ├── bonus_assets/     #   nuvens
│   ├── textures/         #   atlas de paleta 64x64
│   └── catalogo.json     #   índice medido de todos os módulos
├── materials/            # Materiais do Godot (atlas do terreno, oceano)
├── shaders/              # Shader do oceano
├── scenes/
│   ├── main.tscn         # Cena principal
│   ├── player/           # Cena do personagem
│   ├── modules/          # Módulos reutilizáveis do cenário
│   │   ├── terrain/      #   173 cenas, uma por módulo que entra no build
│   │   ├── malhas/       #   malhas em binário, compartilhadas pelas cenas
│   │   ├── props/        #   480 montanhas, de pedras a maciços
│   │   ├── islets/       #   153 ilhas para o mar
│   │   ├── clouds/       #   4 nuvens
│   │   ├── faixas.json   #   terreno por faixa de relevo, gerado do catálogo
│   │   └── acervo.json   #   peças soltas com largura e altura medidas
│   └── world/
│       ├── island/       # Ilha
│       └── ocean/        # Oceano
├── scripts/
│   ├── player/           # Controlador do personagem
│   └── world/            # Gerador da ilha e raiz do mundo
├── tools/                # Scripts de build e de teste (não vão para o build)
├── export_presets.cfg    # Preset de export Web
└── .github/workflows/    # Build e publicação no GitHub Pages
```

## Como o cenário é montado

Os módulos Grid grandes têm todos exatamente 100x100 metros de pegada e as **quatro bordas
na altura zero**, então encaixam entre si em qualquer combinação e em qualquer rotação
múltipla de 90°. O gerador (`scripts/world/gerador_da_ilha.gd`) concentra o relevo forte
numa cadeia curta no miolo, preserva planícies amplas e deforma os vértices de todos os
módulos com uma altura global contínua: a costa fica no nível do mar e o interior sobe até
cerca de 22 metros antes dos relevos locais. A colisão é reconstruída com essa mesma forma.
Um material em coordenadas globais atravessa as peças sem repetir uma textura por célula.
Uma malha costeira procedural contínua envolve a grade, mistura o verde com a areia,
mergulha suavemente no mar e elimina a silhueta quadrada. A mesma semente sempre produz a
mesma ilha.

Para expandir o mapa depois basta mexer nos parâmetros exportados do nó `Ilha`
(raio, semente, irregularidade da costa, quantidade de detalhes) ou acrescentar nomes de
módulos às listas do script — nada precisa ser refeito à mão.

Um detalhe do pacote que vale registrar: boa parte dos módulos Grid são **bacias**, não
elevações. O grupo `d`, por exemplo, são enseadas que afundam até 6 metros abaixo do nível
do mar. Só entram na ilha os módulos que não descem abaixo de -0,3 metro, senão o miolo
ficaria cheio de poços alagados.

## Ferramentas de build

As cenas de módulo, os materiais e as cenas do mundo são gerados por scripts, para poderem
ser refeitos do zero de forma reprodutível:

```bash
godot --headless --path . --import
godot --headless --path . --script tools/setup_project.gd    # mapa de entrada e configurações
godot --headless --path . --script tools/build_materials.gd  # materiais
godot --headless --path . --script tools/build_catalogo.gd   # índice de todos os módulos
godot --headless --path . --script tools/build_modules.gd    # cenas dos módulos usados
godot --headless --path . --script tools/build_world.gd      # oceano, ilha e cena principal
```

## Testes

`tools/testar.gd` roda o jogo sem janela e confere caminhada, corrida, pulo, o bloqueio do
pulo no ar, a colisão com o terreno, o limite da ilha e os limites da câmera. É o mesmo
teste que roda no GitHub Actions antes do export:

```bash
godot --headless --path . --script tools/testar.gd
```

`tools/capturar.gd` abre o jogo com renderização de verdade e grava capturas, para
conferência visual:

```bash
xvfb-run godot --path . --rendering-driver opengl3 --resolution 1280x720 \
  --script tools/capturar.gd -- /tmp/capturas
```

## Build Web

O export usa o preset `Web` **sem threads**: o GitHub Pages não envia os cabeçalhos
`Cross-Origin-Opener-Policy` / `Cross-Origin-Embedder-Policy` exigidos por
`SharedArrayBuffer`, então a variante com threads nem carregaria.

```bash
godot --headless --path . --export-release "Web" build/web/index.html
```

O workflow `.github/workflows/build-web.yml` faz isso a cada push, roda os testes antes e
publica o resultado no GitHub Pages.

## O acervo de módulos

O pacote inteiro está no projeto: **3.263 arquivos `.fbx`** em `assets/grid/`, organizados como
no pacote original (Terrain, Mountains, Islands, River, Ice, Water, nuvens). Todos importados,
sem nenhum erro, e prontos para uso futuro.

`assets/grid/catalogo.json` é o índice que torna esse acervo pesquisável. Ele é gerado por
`tools/build_catalogo.gd`, que abre cada módulo e **mede** — não adivinha pelo nome:

| Campo | O que é |
| --- | --- |
| `largura`, `profundidade` | pegada real em metros |
| `y_min`, `y_max` | até onde a peça desce e sobe |
| `pegada` | 100, 50 ou 25 quando bate com um tamanho de grade |
| `encaixavel` | as quatro bordas estão na altura zero |
| `triangulos` | custo da peça |
| `lod` | se o arquivo é uma cópia de LOD |

Dos 3.263, **1.456 encaixam** em alguma grade. O build do jogo leva **810 módulos**:

| Tipo | No build | De onde vem | Como o cenário usa |
| --- | ---: | --- | --- |
| Terreno | 173 | encaixam em 100 m, sem LOD, não afundam | grade da ilha |
| Montanhas | 480 | todas as `Mountains` sem LOD | marcos, afloramentos e pedras, separados pela largura medida |
| Ilhas | 153 | `Islands` S, M e L sem LOD | ilhotas no mar em volta |
| Nuvens | 4 | `Clouds` | céu |

Um mapa típico coloca ~160 peças e mostra **113 módulos distintos**.

Ficam de fora do build, de propósito:

- **as 47 ilhas `H`** — massas de 445 m com quase 10 mil triângulos cada, feitas para *ser* a
  ilha principal, não enfeite no horizonte; sozinhas pesavam mais que todo o terreno;
- **as 1.579 cópias de LOD** — mesma geometria, e o Godot gera o nível de detalhe sozinho;
- **`River` e `Ice`** (262) — são leitos de rio e placas de gelo que afundam de 1 a 7 metros
  abaixo do nível do mar; entrariam como poços alagados numa ilha tropical;
- **terreno de 50 e 25 m** — encaixa em subgrades que o gerador ainda não subdivide.

**Os 317 MB de `.fbx` de origem ficam de fora do export** (`export_presets.cfg`), então o
acervo completo fica no repositório sem pesar no jogo. Para usar mais peças depois, basta
afrouxar os filtros em `tools/build_modules.gd`.

As malhas assadas guardam só posição, normal e índices: as coordenadas de textura não são
lidas por ninguém, já que o cenário é pintado pelo shader em coordenadas globais. Descartá-las
cortou cerca de um quarto do tamanho de cada malha.

Um detalhe do formato: cada arquivo `_LOD.fbx` guarda **três malhas sobrepostas** (LOD0, LOD1 e
LOD2). O build usa apenas a LOD0; instanciar o arquivo inteiro desenharia geometria repetida no
mesmo lugar. O Godot cuida do nível de detalhe sozinho.

## Assets

Os assets vêm do pacote **Low Poly Modular Terrain Pack v1.4**, publicado no release
[`Assets-Release`](https://github.com/Botopai50/jogo-3d-godot/releases/tag/Assets-Release)
deste repositório. Detalhes do que foi importado estão em
[`assets/grid/CREDITOS.md`](assets/grid/CREDITOS.md).

> **Aviso de licença.** O pacote acompanha um `License.pdf` com os termos da Unity Asset
> Store EULA, que permitem usar os assets dentro de um jogo (inclusive comercialmente), mas
> **proíbem redistribuir ou repassar os arquivos de asset em si**, mesmo modificados.
> Publicar o jogo exportado é uso permitido. Já manter os 3.263 `.fbx` e as texturas
> versionados num repositório público, e o pacote completo como release público, é
> redistribuição — e agora é o pacote inteiro, não mais um subconjunto.
> Se a intenção for ficar dentro da licença, o caminho é tornar o repositório privado (ou
> remover o release e os arquivos de origem) e deixar público apenas o build.
