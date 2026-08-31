# Sistema de hidrologia

O sistema novo não usa o antigo planejador ou a antiga inundação baseada na
malha do terreno. O gerador da ilha fornece somente o grid disponível, o
tamanho do tile e uma função para consultar a altura ampla do mundo.

Fluxo ativo:

`Terrain Grid -> HydrologyPlanner -> HydrologyManager -> WaterGeometryGenerator`

- `HydrologyPlanner` escolhe deterministicamente nascente, caminho, lago e
  terminal oceânico. Também seleciona e rotaciona os módulos físicos.
- `WaterTileData` contém tipo (`NONE`, `RIVER`, `LAKE`), nível, largura,
  máscara, pontos de controle e sockets.
- `RiverConnection` representa lado, posição exata, largura, altura, tipo e
  identificador do socket, incluindo rotação e tolerâncias de compatibilidade.
- `RiverPath` guarda o caminho contínuo, interpola curvas e identifica trechos
  cuja diferença de altura permite inserir cachoeiras futuramente.
- `HydrologyManager` harmoniza bordas compartilhadas, valida vizinhos, monta
  componentes contínuos e controla a visualização de depuração.
- `WaterGeometryGenerator` cria rios e lagos independentemente dos vértices do
  fundo. Lagos são planos; rios interpolam somente seus pontos de controle.

## Máscaras

Cada tile possui uma máscara horizontal. Lagos usam polígonos fechados e rios
usam o eixo procedural com largura. A representação é independente do formato
vertical do terreno e pode ser substituída posteriormente por dados importados
ou texturas sem alterar o gerador de geometria.

## Debug

Ative `debug_enabled` no `HydrologyManager` para mostrar sockets, direções,
caminhos, limites das máscaras, níveis, identificação dos tiles e mensagens de
incompatibilidade. A cena `res://scenes/tests/hydrology_test.tscn` demonstra
reta, curva, descida, lago com entrada/saída e conexão com o oceano.

## Testes

```powershell
godot --headless --path . --script tools/testar_hidrologia.gd
godot --headless --path . --script tools/testar.gd
```

