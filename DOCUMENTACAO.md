# Fits on Fire — Documentação Técnica

> Jogo de ação cooperativo top-down 2D, desenvolvido em **Godot 4.6**, com narrativa
> sobre combater a "Inércia" através do movimento. Inclui um NPC narrador com IA
> generativa (Google Gemini 2.5 Flash).

---

## Índice

1. [Visão geral](#1-visão-geral)
2. [Conceito e narrativa](#2-conceito-e-narrativa)
3. [Requisitos e configuração](#3-requisitos-e-configuração)
4. [Estrutura do projeto](#4-estrutura-do-projeto)
5. [Configuração da engine (`project.godot`)](#5-configuração-da-engine-projectgodot)
6. [Controles](#6-controles)
7. [Arquitetura geral](#7-arquitetura-geral)
8. [Sistemas e scripts](#8-sistemas-e-scripts)
9. [Fluxo de cenas e progressão](#9-fluxo-de-cenas-e-progressão)
10. [Sistema de combate](#10-sistema-de-combate)
11. [Sistema de spawn de inimigos](#11-sistema-de-spawn-de-inimigos)
12. [Inimigos e boss](#12-inimigos-e-boss)
13. [NPC com IA (Gemini)](#13-npc-com-ia-gemini)
14. [Interface (HUD e barras de vida)](#14-interface-hud-e-barras-de-vida)
15. [Grupos e camadas de física](#15-grupos-e-camadas-de-física)
16. [Convenções de código](#16-convenções-de-código)
17. [Como estender o jogo](#17-como-estender-o-jogo)

---

## 1. Visão geral

| Item | Valor |
|------|-------|
| **Nome** | `fits_on_fire` |
| **Engine** | Godot 4.6 (renderização **GL Compatibility**) |
| **Linguagem** | GDScript |
| **Gênero** | Ação cooperativa top-down (beat 'em up / arena) |
| **Jogadores** | 2 (co-op local — Guerreiro e Mago) |
| **Resolução** | Viewport 960×540, janela 1280×720 (stretch `viewport`) |
| **Física 2D** | Padrão Godot · Física 3D configurada para Jolt (não usada no gameplay 2D) |
| **Cena inicial** | `scenes/house.tscn` (UID `uid://cwxoxvf0nnqla`) |
| **Autoload** | `SceneCycle` (`scripts/scene_cycle.gd`) |

O jogo é desenvolvido pela organização **VCPC-UniFECAF**. Toda a narrativa, comentários
de código e mensagens de erro estão em **português do Brasil**.

---

## 2. Conceito e narrativa

A história gira em torno da **Inércia** — uma névoa que suprime a vontade de viver e
"trava o metabolismo do planeta". O mundo viveu a *Era do Movimento* (energia cinética
alimentava a terra), seguida pela *Grande Letargia* (conforto extremo). Os jogadores
controlam o **Guerreiro** e o **Mago**, anomalias capazes de reacender a *Chama
Endorfínica*.

Os inimigos são metáforas de problemas físicos/comportamentais:

| Inimigo | Representa |
|---------|-----------|
| **Zumbis** | "Atrofia Extrema" — pessoas que se entregaram à apatia |
| **Lobisomens (Wolf)** | "Estresse Acumulado" — energia reprimida sem válvula de escape física |
| **Orcs** | "Massa sem Disciplina" — consumo sem gasto calórico |
| **Dragão Calórico (Boss)** | A Inércia condensada no núcleo do mundo |

A lore é entregue progressivamente pelo NPC **Wise** (Velho Sábio), fase a fase, via IA
generativa (ver [seção 13](#13-npc-com-ia-gemini)).

---

## 3. Requisitos e configuração

### Pré-requisitos
- **Godot Engine 4.6** (recurso `4.6` declarado em `project.godot`).
- Chave de API do **Google Gemini** (para o NPC Wise) — obtida em
  <https://aistudio.google.com/apikey>.

### Configuração da chave de API
O NPC `wise.gd` lê a chave de um arquivo `res://.env` (não versionado — está no
`.gitignore`):

```bash
# 1. Copie o template
cp .env.example .env

# 2. Edite .env e preencha a chave
GEMINI_API_KEY=sua_chave_real_aqui
```

Sem a chave, o jogo funciona normalmente, mas o diálogo com o Wise exibe um erro
("Chave API ausente ou placeholder em .env").

### Executando
Abra o projeto no editor Godot 4.6 e pressione **F5**, ou rode `house.tscn` diretamente.
A cena inicial é a Casa.

---

## 4. Estrutura do projeto

```
fits_on_fire/
├── project.godot          # Configuração da engine, inputs, autoloads
├── export_presets.cfg     # Presets de exportação
├── .env.example           # Template da chave Gemini (copie p/ .env)
├── icon.svg               # Ícone do projeto
│
├── scenes/                # Fases (níveis) jogáveis
│   ├── house.tscn         # Fase 1 — A Casa (cena inicial)
│   ├── woods.tscn         # Fase 2 — O Bosque
│   ├── forest.tscn        # Fase 3 — A Floresta Densa
│   ├── ruins.tscn         # Fase 4 — As Ruínas
│   ├── cave.tscn          # Fase 5 — A Caverna (pré-boss)
│   ├── dragons_nest.tscn  # Fase 6 — O Ninho do Dragão (pós-boss)
│   └── main.tscn          # Cena de demonstração / teste do boss
│
├── prefabs/               # Cenas reutilizáveis (PackedScene)
│   ├── player_warrior.tscn / player_wizard.tscn / player_1.tscn
│   ├── zombie.tscn / wolf.tscn / orc.tscn / dragon_boss.tscn
│   ├── projectile.tscn / hitbox.tscn
│   ├── spawn_point.tscn / activate_spawn.tscn
│   ├── portal.tscn / wise.tscn / hud.tscn
│
├── scripts/               # GDScript (.gd) + arquivos .uid da engine
│   └── (detalhados na seção 8)
│
└── sprites/               # Arte
    ├── Characters(100x100)/
    ├── Enemies/
    ├── interface/
    ├── scenerios/
    └── Guns.png
```

> **Nota:** os arquivos `.uid` e `.import` são gerados/gerenciados pela Godot — não
> edite manualmente. Arquivos `scenes/main.tscn*.tmp` são temporários do editor.

---

## 5. Configuração da engine (`project.godot`)

| Seção | Configuração |
|-------|-------------|
| `application` | Nome, cena principal (`house.tscn`), features `4.6` + GL Compatibility |
| `autoload` | `SceneCycle` carregado globalmente como singleton |
| `display` | Viewport 960×540, janela 1280×720, stretch `viewport` |
| `global_group` | `player`, `enemy`, `player_attack`, `boss` |
| `input` | Mapeamentos para 2 jogadores (teclado + 2 joypads + mouse) |
| `layer_names` | Camada física 1 = `player`, camada 2 = `enemy` |
| `rendering` | `gl_compatibility` (desktop e mobile), driver D3D12 no Windows |

---

## 6. Controles

### Jogador 1 (teclado WASD + joypad 0)
| Ação | Teclado | Joypad |
|------|---------|--------|
| Mover | `W` `A` `S` `D` | Stick esquerdo |
| Ataque leve (`p1_light`) | `J` | Botão 10 |
| Ataque pesado (`p1_heavy`) | `K` | Gatilho direito (eixo 5) |
| Mirar (`p1_aim_*`) | — | Stick direito |

### Jogador 2 (teclado setas + joypad 1 + mouse)
| Ação | Teclado | Outros |
|------|---------|--------|
| Mover | Setas direcionais | Stick esquerdo (joypad 1) |
| Ataque leve (`p2_light`) | `1` | Botão esq. mouse / botão 10 |
| Ataque pesado (`p2_heavy`) | `2` | Botão dir. mouse / gatilho |
| Mirar (`p2_aim_*`) | — | Stick direito / mouse |

### Ações globais
| Ação | Tecla | Função |
|------|-------|--------|
| `interact` | `E` / botão 3 do joypad | Conversar com o NPC Wise |
| `cycle_scene` | `Espaço` | Pular para a próxima fase (debug/demo) |
| `ui_cancel` | `Esc` | Fechar o diálogo do Wise |

> O Mago (`wand.gd`) só mira com o mouse quando é o Jogador 2, ou quando não há
> joypads conectados, ou em modo single-player.

---

## 7. Arquitetura geral

O jogo segue o paradigma **composição por cenas** da Godot, com uma hierarquia de
herança clara para entidades:

```
PlayerBase (CharacterBody2D)        EnemyBase (Area2D)
├── Warrior (corpo a corpo)         ├── Zombie (perseguidor simples)
└── Wizard  (projéteis + Wand)      ├── Wolf   (máquina de estados c/ ataque)
                                    └── Orc    (máquina de estados c/ espada)

DragonBoss (Node2D)                 — máquina de estados própria (sem herança)
```

**Pilares arquiteturais:**

- **Grupos como contrato:** entidades se comunicam por grupos (`player`, `enemy`,
  `boss`, `player_attack`) em vez de referências diretas — desacoplamento total.
- **Duck typing defensivo:** uso recorrente de `has_method("take_damage")`,
  `has_method("is_alive")` e `"health" in node` antes de chamar — robusto a cenas
  mal configuradas.
- **Resources de dados:** ondas de inimigos são descritas por `WaveConfig` e
  `WaveSpawnEntry` (Resources `@export`-áveis pelo Inspector), separando dados de
  lógica.
- **Autoload (`SceneCycle`):** singleton global para troca de cenas via tecla.
- **`call_deferred` em mudanças estruturais:** spawns, mudança de cena e exceções de
  colisão usam chamadas deferidas para respeitar o ciclo de física.

---

## 8. Sistemas e scripts

Visão geral de cada script em `scripts/`:

| Script | `class_name` / Base | Responsabilidade |
|--------|---------------------|------------------|
| `player_base.gd` | `PlayerBase` / `CharacterBody2D` | Base dos jogadores: movimento, estados, vida, ataques, limite de distância entre parceiros |
| `warrior.gd` | — / `PlayerBase` | Guerreiro: ataques corpo a corpo via `hitbox` |
| `wizard.gd` | — / `PlayerBase` | Mago: dispara projéteis usando a `Wand` |
| `wand.gd` | `Wand` / `Node2D` | Lógica de mira do mago (stick/mouse), posição da muzzle |
| `player.gd` | — / `CharacterBody2D` | **Protótipo legado** de jogador (não usar) |
| `player_base.gd` | (ver acima) | — |
| `enemy_base.gd` | — / `Area2D` | Base dos inimigos: perseguição, flanqueamento, separação, dano de contato, morte |
| `zombie.gd` | — / `enemy_base` | Inimigo lento que apenas persegue |
| `wolf.gd` | — / `enemy_base` | Máquina de estados CHASE/ATTACK/COOLDOWN com hitbox de ataque |
| `orc.gd` | — / `enemy_base` | Igual ao Wolf, com espada e animações próprias |
| `enemy.gd` | — / `enemy_base` | **Deprecado** — usar `enemy_base` + subclasses |
| `dragon_boss.gd` | — / `Node2D` | Boss com 4 ataques (CLAW/TAIL/WING/FIRE) e IA por distância |
| `hitbox.gd` | — / `Area2D` | Hitbox temporária de ataque corpo a corpo (Guerreiro/inimigos) |
| `projectile.gd` | — / `Area2D` | Projétil do Mago, move-se e aplica dano ao colidir |
| `enemy_spawner.gd` | `EnemySpawner` / `Node2D` | Orquestra ondas de inimigos |
| `wave_config.gd` | `WaveConfig` / `Resource` | Dados de uma onda (entries, timing, modo de avanço) |
| `wave_spawn_entry.gd` | `WaveSpawnEntry` / `Resource` | Uma entrada de spawn (cena, quantidade, ponto) |
| `spawn_point.gd` | `SpawnPoint` / `Marker2D` | Ponto de spawn; instancia o inimigo |
| `activate_spawn.gd` | `ActivateSpawn` / `Area2D` | Gatilho que inicia o spawner ao jogador entrar |
| `portal.gd` | — / `Area2D` | Transição para a próxima fase quando inimigos derrotados |
| `scene_cycle.gd` | — / `Node` (autoload) | Troca de cena pela tecla `Espaço` |
| `camera_follow.gd` | — / `Camera2D` | Câmera que segue os 2 jogadores com zoom dinâmico |
| `health_bar.gd` | `HealthBar` / `Control` | Barra de vida do HUD (jogadores) |
| `enemy_health_bar.gd` | `EnemyHealthBar` / `Control` | Barra de vida flutuante (inimigos), desenhada pixel a pixel |
| `hud.gd` | — / `CanvasLayer` | Liga as barras de vida aos jogadores |
| `wise.gd` | — / `Area2D` | NPC narrador com diálogo via API Gemini |

---

## 9. Fluxo de cenas e progressão

### Ordem das fases (`scene_cycle.gd`)
```gdscript
SCENE_ORDER = [
    "house.tscn",        # 1 — A Casa
    "woods.tscn",        # 2 — O Bosque
    "forest.tscn",       # 3 — A Floresta Densa
    "ruins.tscn",        # 4 — As Ruínas
    "cave.tscn",         # 5 — A Caverna (pré-boss)
    "dragons_nest.tscn", # 6 — O Ninho do Dragão (pós-boss)
]
```

### Dois mecanismos de avanço de fase

1. **Portal (`portal.gd`) — avanço por objetivo:**
   - Só transiciona quando **todos os jogadores vivos** estão dentro do portal
     **E** não há inimigos vivos na cena.
   - O destino é configurado em `next_level_path` (caminho `.tscn` por export).
   - Aciona uma `SceneTransition` (autoload opcional `root/SceneTransition`) se existir.

2. **`SceneCycle` (autoload) — avanço por debug/demo:**
   - Tecla `Espaço` pula para a próxima cena na lista `SCENE_ORDER` (cíclico).
   - Útil para apresentações e testes; ignora a condição de inimigos.

---

## 10. Sistema de combate

### Jogadores (`player_base.gd`)

Máquina de estados: `IDLE → MOVE → ATTACK_LIGHT / ATTACK_HEAVY → HIT → DEAD`.

- **Vida:** `max_health = 100` (export). Emite o sinal `health_changed(current, maximum)`.
- **Ataques:** o `PlayerBase` define o esqueleto (`_start_light_attack`,
  `_start_heavy_attack`) e delega `_perform_light_attack()` / `_perform_heavy_attack()`
  às subclasses (padrão *template method*).
- **Cooldown:** ataque pesado tem cooldown (`heavy_cooldown`, 1.5s padrão).
- **Invencibilidade temporária:** ao tomar dano, `can_be_hit = false` por 0.5s.
- **Knockback:** desliza por `KNOCKBACK_SLIDE_DURATION` (0.2s) na direção oposta ao
  atacante.
- **Limite de distância entre parceiros:** os dois jogadores não podem se afastar mais
  que `max_player_distance` (lido da câmera) — implementado por
  `_apply_partner_velocity_limit()` e `_apply_partner_position_clamp()`.
- **Exceção de colisão:** jogadores não colidem entre si
  (`add_collision_exception_with`).

#### Guerreiro (`warrior.gd`)
- Ataque leve: 15 de dano (hitbox 0.2s); pesado: 35 de dano (hitbox 0.35s).
- Instancia `prefabs/hitbox.tscn` à frente do personagem, com knockback
  (20 ou 40 conforme o dano).

#### Mago (`wizard.gd` + `wand.gd`)
- Ataque leve: rajada de projéteis (`light_projectile_count`, dano 8 cada).
- Ataque pesado: projétil grande (dano 40, cooldown 2.5s).
- `Wand` calcula a direção de mira (stick direito ou mouse) e a posição da muzzle.

### Hitbox (`hitbox.gd`) e Projétil (`projectile.gd`)
- Ambos entram no grupo `player_attack` e têm `damage`/`knockback` configuráveis.
- `_resolve_target()` aceita o nó ou seu pai se for do grupo `enemy`/`boss` e tiver
  `take_damage`.
- `hitbox` é temporária (`lifetime`, padrão 0.15s) e atinge cada alvo só uma vez.
- `projectile` move-se em linha reta, aplica dano e se destrói no primeiro acerto.

### Inimigos (`enemy_base.gd`)
- **Vida + knockback + dano de contato** (`contact_damage` com `contact_cooldown`).
- **Perseguição com flanqueamento:** quando perto, mira numa posição lateral ao
  jogador (`_get_flank_position`) para não empilhar.
- **Separação:** empurra-se para longe de outros inimigos a menos de 20px (boids
  simplificado).
- Recebe dano de áreas no grupo `player_attack` ou aplica dano em jogadores no contato.

---

## 11. Sistema de spawn de inimigos

Arquitetura orientada a dados, configurável pelo Inspector:

```
ActivateSpawn (Area2D, gatilho)
      │ jogador entra → start()
      ▼
EnemySpawner (Node2D)
      ├── waves: Array[WaveConfig]
      │        └── entries: Array[WaveSpawnEntry]  (cena, quantidade, ponto, delays)
      └── spawn_points: Array[SpawnPoint]  (Marker2D que instancia o inimigo)
```

### `EnemySpawner` (`enemy_spawner.gd`)
- **Sinais:** `wave_started`, `wave_completed`, `all_waves_completed`.
- **Resolução de pontos:** usa `spawn_points` explícitos ou autocoleta filhos
  `SpawnPoint` / nós do grupo `spawn_point`.
- **Modo de avanço de onda (`WaveAdvanceMode`):**
  - `DELAY` — espera um tempo fixo entre ondas.
  - `CLEAR_ALL` — só avança quando todos os inimigos da onda morrem (padrão).
  - `BOTH` — combina: espera a limpeza, depois completa o tempo mínimo restante.
- `one_shot = true` impede o spawner de rodar mais de uma vez.

### `WaveConfig` (Resource)
Campos: `display_name`, `entries`, `delay_between_spawns`, `delay_before_wave`,
`advance_mode` (com opção `INHERIT` para herdar do spawner), `delay_after_wave`.

### `WaveSpawnEntry` (Resource)
Campos: `enemy_scene` (PackedScene), `count` (1–99), `delay_between_spawns`,
`spawn_point_index` (-1 = alterna entre pontos).

### `ActivateSpawn` (`activate_spawn.gd`)
- `Area2D` que dispara `spawner.start()` quando um jogador vivo entra.
- `trigger_once` (padrão) desativa o monitoramento após o primeiro acionamento.

---

## 12. Inimigos e boss

### Zombie (`zombie.gd`)
O mais simples: apenas perseguição (`speed = 28`), sem ataque dedicado — causa dano por
contato herdado do `enemy_base`.

### Wolf (`wolf.gd`) e Orc (`orc.gd`)
Praticamente idênticos em lógica — máquina de estados:
`CHASE → ATTACK → COOLDOWN`.
- Perseguem até `attack_range` (28px), então atacam com uma `SwordHitbox` direcionada
  ao jogador.
- Dano de ataque: 20; cooldown: 1s; duração do ataque: 0.35s.
- A hitbox fica ativa apenas durante ~55% da animação de ataque.
- Diferença principal: animações (`slash`/`attack` no Wolf; `walk`/`idle`/`hit` no Orc).

### Dragon Boss (`dragon_boss.gd`)
Boss complexo (`Node2D`, vida 500), com máquina de estados própria:
`IDLE → WINDUP → ACTIVE → RECOVER`.

**Quatro ataques (`AttackType`):**

| Ataque | Dano | Quando é escolhido | Cooldown |
|--------|------|--------------------|----------|
| `CLAW` (garra) | 18 | Distância < 90px | 1.2s |
| `TAIL` (cauda) | 22 | Probabilístico (25%) | 2.5s |
| `WING` (asa) | 12 | ≥2 jogadores na faixa 90–150px, ou após garras consecutivas; aplica knockback | 3.0s |
| `FIRE` (fogo) | 35 | Longa distância (>140px) ou com vida < 50% e dist >100px | 5.0s |

**Comportamento:**
- **Mira/facing:** `FacingPivot` rotaciona/espelha o boss em direção ao jogador mais
  próximo (a cauda inverte a direção).
- **Reposicionamento:** aproxima-se até `reposition_distance` (180px), respeitando os
  limites da arena (derivados dos limites da câmera + `arena_margin`).
- **Escalonamento por vida:** abaixo de 50% de vida, prioriza o ataque de fogo.
- **Hitboxes separadas** por ataque (`ClawHitbox`, `TailHitbox`, `WingHitbox`,
  `FireHitbox`), ativadas só na fase `ACTIVE`.
- **Morte:** toca animação `death` e se remove (`queue_free`).

---

## 13. NPC com IA (Gemini)

O **Wise** (`wise.gd`) é um `Area2D` que entrega a lore do jogo conversando com o
jogador via **Google Gemini 2.5 Flash**.

### Funcionamento
1. Ao entrar no alcance do Wise, surge o prompt `▲ Interagir` (ou
   `Derrote os inimigos primeiro` se houver inimigos vivos).
2. Pressionar `interact` (E) abre o diálogo — **só se não houver inimigos vivos**.
3. Durante o diálogo, **todos os jogadores são congelados** (`set_physics_process(false)`).
4. O jogador digita texto; `Enter` envia, `Esc` fecha.
5. A resposta vem da API Gemini, mantendo histórico de conversa.

### Contexto por fase (`LORE_POR_FASE`)
O `fase_atual` (1–6, export) seleciona uma *system instruction* diferente, definindo
a personalidade do "Velho Sábio Misterioso" e quais segredos revelar gradualmente em
cada cena (Casa, Bosque, Floresta, Ruínas, Caverna, Ninho).

### Detalhes da API
- **Endpoint:** `generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent`
- **Autenticação:** chave lida de `res://.env` (`GEMINI_API_KEY=`).
- **Config de geração:** `maxOutputTokens: 256`, `temperature: 0.9`.
- **Instrução de sistema:** respostas breves (1–3 frases), sempre em personagem, em
  PT-BR.
- Tratamento de erros para chave ausente, falha HTTP, JSON inválido e resposta vazia.

> ⚠️ **Segurança:** a chave fica em `.env` (ignorado pelo Git). Nunca commite a chave
> real. A requisição é feita client-side pela engine.

---

## 14. Interface (HUD e barras de vida)

### HUD (`hud.gd`)
- `CanvasLayer` com duas `HealthBar` (`lifeplayer1`, `lifeplayer2`).
- Em `_ready` (deferido), liga cada barra ao jogador correspondente pelo `player_id`.

### HealthBar (`health_bar.gd`) — jogadores
- `Control` com label do jogador, fundo, preenchimento e percentual.
- Cor muda de verde (`#6bbf59`) para vermelho (`#c44b33`) abaixo de 30% de vida.
- Transição animada via `Tween` (0.25s).
- Atualiza-se reagindo ao sinal `health_changed` do jogador (padrão observer).

### EnemyHealthBar (`enemy_health_bar.gd`) — inimigos
- Barra flutuante **desenhada pixel a pixel** em `_draw()` (estética pixel-art com
  borda arredondada custom).
- Vincula-se ao host via `bind_host()` e some quando o inimigo morre.

---

## 15. Grupos e camadas de física

### Grupos (contrato de comunicação)
| Grupo | Membros | Uso |
|-------|---------|-----|
| `player` | Jogadores | Alvos de inimigos, gatilhos, câmera |
| `enemy` | Todos os inimigos | Detecção de "fase limpa", alvos de ataques |
| `boss` | Dragão | Alvo de ataques (além de `enemy`) |
| `player_attack` | Hitboxes e projéteis | Detecção de dano em inimigos |
| `spawn_point` | Marcadores de spawn | Autocoleta pelo spawner |
| `portal` | Portais | (organizacional) |

### Camadas de física 2D
| Camada | Nome |
|--------|------|
| 1 | `player` |
| 2 | `enemy` |

> Inimigos (`Area2D`) usam `collision_mask = 1` para detectar jogadores; o portal e o
> gatilho de spawn também monitoram a camada 1.

---

## 16. Convenções de código

Padrões observados no código (siga-os ao contribuir):

- **Tipagem estática** sempre que possível (`var x: int`, retornos tipados).
- **Membros privados** prefixados com `_` (`_state_timer`, `_resolve_spawner()`).
- **`@export`** para tudo que designers ajustam no Inspector; **`@onready`** para
  referências a nós-filhos.
- **`class_name`** apenas onde o tipo é referenciado externamente (`PlayerBase`,
  `EnemySpawner`, `WaveConfig`, etc.).
- **Comentários e strings** em português do Brasil.
- **Programação defensiva:** checar `is_instance_valid()`, `has_method()`,
  `has_node()` e `"campo" in node` antes de acessar.
- **`call_deferred`/`set_deferred`** para mudanças estruturais durante a física.
- **Comunicação por sinais e grupos**, evitando acoplamento direto entre cenas.
- **`.editorconfig`:** UTF-8, indentação por tabs (padrão Godot).

---

## 17. Como estender o jogo

### Adicionar um novo tipo de inimigo
1. Crie `scripts/meu_inimigo.gd` estendendo `"res://scripts/enemy_base.gd"`.
2. Sobrescreva `_process_enemy(delta)` para o comportamento (ou reuse `move_chase`).
3. Crie um prefab `prefabs/meu_inimigo.tscn` (Area2D com `AnimatedSprite2D`,
   `CollisionShape2D` e `EnemyHealthBar`).
4. Referencie a cena em um `WaveSpawnEntry` de alguma `WaveConfig`.

### Adicionar uma nova fase
1. Crie `scenes/minha_fase.tscn` (copie a estrutura de uma fase existente: TileMap,
   `Camera2D` com `camera_follow.gd`, jogadores, HUD, Wise, Portal, EnemySpawner).
2. Configure o `Portal.next_level_path` da fase anterior para apontar à nova.
3. (Opcional) Adicione o caminho em `SCENE_ORDER` no `scene_cycle.gd` para o pulo por
   tecla.
4. Ajuste `Wise.fase_atual` para o contexto narrativo correto.

### Criar uma onda de inimigos
1. No `EnemySpawner` da cena, adicione um `WaveConfig` em `waves`.
2. Dentro dele, adicione `WaveSpawnEntry` (cena do inimigo + quantidade + ponto).
3. Posicione `SpawnPoint` (Marker2D) na cena.
4. Adicione um `ActivateSpawn` (Area2D) apontando para o spawner, se quiser disparo por
   gatilho.

### Adicionar um novo personagem jogável
1. Crie um script estendendo `PlayerBase`.
2. Implemente `_perform_light_attack()` e `_perform_heavy_attack()`.
3. (Opcional) Sobrescreva `_get_light_attack_duration()` / `_get_heavy_attack_duration()`.
4. Crie o prefab com `AnimatedSprite2D` e as animações esperadas (`idle`, `walk_side`,
   `walk_up`/`up`, `walk_down`/`down`, `attack_light`, `attack_heavy`, `hit`, `death`).

---

*Documentação gerada a partir da análise do código-fonte. Para dúvidas sobre
comportamento específico, consulte os scripts em `scripts/` — são pequenos, tipados e
comentados em português.*
