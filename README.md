# Jogo 3D Godot

Protótipo de um **jogo 3D em primeira pessoa** desenvolvido na **Godot Engine 4.7.2 (stable)**.

A meta do projeto é um protótipo jogável no navegador: um personagem em primeira pessoa que
anda, corre e pula, explorando uma **ilha grande cercada pelo mar**, construída com **assets
modulares Grid**.

> **Por que Godot 4.7.2 e não 4.8?** A linha 4.8 ainda está em desenvolvimento (apenas
> snapshots `4.8-dev*`, não recomendados para produção). A versão estável mais recente é a
> `4.7.2-stable`, que também é a que possui templates de export Web estáveis.

## Estado atual

| Etapa | Descrição | Estado |
| :---: | --- | --- |
| 1 | Criação do repositório e estrutura inicial do projeto Godot | ✅ concluída |
| 2 | Download e análise do pacote de assets modulares Grid (release) | ⏳ aguardando o release |
| 3 | Protótipo: personagem em primeira pessoa, ilha modular e build Web | ⏳ pendente |

Nesta etapa o repositório contém **apenas o esqueleto do projeto**. Ainda **não** existem
personagem, mapa, assets importados nem configuração de build — isso é intencional.

## Requisitos

- [Godot Engine 4.7.2 stable](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable)
  (versão padrão, sem .NET)

## Como abrir o projeto

1. Clone o repositório.
2. Abra o Godot 4.7.2 e clique em **Import**.
3. Selecione o arquivo `project.godot` na raiz do repositório.

O renderizador está configurado como **Compatibility (OpenGL)**, que é o modo compatível com
export para navegador.

## Estrutura de pastas

```
.
├── assets/              # Assets importados
│   └── grid/            # Pacote modular Grid (chega na etapa 2)
├── materials/           # Materiais (.tres)
├── textures/            # Texturas
├── scenes/
│   ├── player/          # Cenas do personagem
│   ├── modules/         # Módulos reutilizáveis do cenário
│   └── world/
│       ├── island/      # Elementos da ilha
│       └── ocean/       # Elementos do oceano
├── scripts/
│   ├── player/          # Scripts do personagem
│   └── world/           # Scripts do cenário
└── project.godot
```

As pastas vazias são mantidas no Git por arquivos `.gitkeep` e serão preenchidas nas próximas
etapas.

## Licença

Definir.
