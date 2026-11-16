# Capítulo 83 — Performance

## Objetivo

Ao final deste capítulo você deve conseguir:

- rever um orçamento de frame **planejado** contra o jogo **inteiro**, e traduzir limites por estágio em critérios que uma máquina consegue verificar;
- reproduzir os **piores casos** da Vigília em pontos fixos: a caçada no corredor, o frame do checkpoint, a passagem fria (PSO) e o Salão das Turbinas;
- configurar a **escalabilidade** (`sg.*`, `DefaultScalability.ini`) e escolher o preset inicial por detecção, sem entregar a decisão a um benchmark genérico;
- medir **memória** (`stat memory`, `memreport`, LLM) e **tempos de carregamento** por nível e por setor;
- montar um **portão de performance**: uma rota fixa no build Test, um relatório em linhas e um juiz (`Tools/perf_gate.py`) que reprova o build quando o orçamento (`Tools/perf_budget.json`) estoura.

---

## Contexto

O Capítulo 58 fixou o orçamento da Vigília com um rótulo honesto: **[DECISÃO DE PROJETO, revisto no Capítulo 83]**. Na época, só o setor 1 existia, o Salão das Turbinas era "futuro", e a sessão de profiling do Capítulo 59 foi declarada **[HIPOTÉTICO]**. Desde então, a Parte XI construiu a Subestação, o Salão, a perseguição e o final, e o vertical slice (Capítulo 78) vestiu o corredor com arte, luz e efeitos de qualidade final.

Três compromissos cobram este capítulo:

- o registro de riscos do Capítulo 76 tem uma linha "Performance no Salão das Turbinas", com o gatilho "mais de 16,67 ms na máquina-alvo (Cap. 83)";
- o Milestone 9 (*Polish*) fecha com os Capítulos 82 e 83;
- o Capítulo 84 precisa de um critério de release que não dependa de alguém lembrar de rodar `VGPerfHunt` antes de empacotar.

Medir à mão funciona enquanto alguém se lembra de medir. Cada sala, material ou efeito novo pode quebrar o orçamento em silêncio, até o primeiro playtest numa máquina comum. Este capítulo transforma o orçamento num **teste**.

Uma regra para o capítulo inteiro: **nenhum número aqui é uma medição.** Os limites são decisões, com o motivo escrito. As saídas de exemplo são **[HIPOTÉTICO]**, e as tabelas de resultado são modelos para você preencher com o seu build e a sua máquina-alvo (`docs/tech/maquina-alvo.md`, Capítulo 58).

---

## 83.1 O orçamento, revisto

O orçamento do Capítulo 58 tem três camadas: o alvo (60 FPS a 1080p na máquina-alvo, preset Médio), as regras de frame (estágios abaixo de 14 ms, nenhum frame acima de 33 ms, captura do checkpoint em até 2 ms) e as fatias por sistema (IA 1,0 ms, Lumen 7,0 ms...). Medindo automaticamente no build **Test**, duas camadas não se verificam diretamente:

- a linha `PERF` do `VGPerfCapture` traz o **tempo de frame** (média, p95, p99, máximo) e o estágio que mais limitou, mas não o tempo de cada estágio;
- no Test, os *stats* podem não existir (⚠️ depende dos *defines* da configuração na sua versão; não conte com `stat Vigilia` lá), e o `STAT_VGSaveCapture` do checkpoint some junto.

A revisão, então, traduz cada regra em algo que a linha `PERF` mostra:

| Regra do Capítulo 58 | Como o portão verifica | Por quê |
|---|---|---|
| 60 FPS (16,67 ms) | **p99** do frame ≤ 16,7 ms | No máximo 1 frame em 100 acima do orçamento num cenário de pior caso |
| Cada estágio ≤ 14 ms no pior cenário | **p95** do frame ≤ 14,0 ms | O frame é aproximadamente o estágio mais lento mais a sincronização (seção 58.3); se 95% dos frames cabem em 14 ms, a folga de 2,67 ms existe na maior parte do tempo **[SIMPLIFICAÇÃO DIDÁTICA]** |
| Nenhum frame > 33 ms fora de carregamento | **máximo** ≤ 33,3 ms, na **pior** repetição, frio incluído | Um *hitch* é um evento, e não uma tendência: não tem mediana |
| Captura do checkpoint ≤ 2 ms | **máximo** ≤ 16,7 ms na janela que contém o save | Com o resto do frame dentro de 14 ms, 14 + 2 cabe em 16,67; sem *stats*, o frame inteiro é a evidência |
| Fatias por sistema (IA 1,0, Lumen 7,0...) | Não verifica | São ferramentas de **diagnóstico**: quando o portão reprova, o Insights (Cap. 59) diz qual fatia estourou |

A última linha é a decisão mais importante da revisão. As fatias por sistema continuam dizendo a cada sistema qual é o seu teto, e é com elas que se discute "quem cede 2 ms". Mas não reprovam um build: isso exigiria instrumentação que o Test não tem, e falharia por ruído. O portão olha o que a jogadora sente (o frame); o diagnóstico olha o porquê.

> 🌉 **Ponte:** é o SLO de latência de um serviço: "p99 abaixo de 200 ms" em vez de "média abaixo de 100 ms", porque a média esconde a cauda que o usuário sente.
>
> 🧱 **Onde a ponte cai:** um serviço é medido por minuto, sobre milhares de requisições, e um pico isolado vira estatística. Num jogo, o frame é um **prazo duro** a cada 16,67 ms, e um único frame de 50 ms no meio da perseguição é visto, sentido e lembrado. Por isso o portão tem uma regra de **máximo**, que um SLO típico não tem.

### O Médio é o mesmo jogo?

O alvo diz "preset Médio", e o Capítulo 58 deu ao Lumen a maior fatia da GPU. Antes de medir, confira o que o Médio **contém**. ⚠️ No `BaseScalability.ini` de várias versões 5.x, o grupo de iluminação global (`sg.GlobalIlluminationQuality`) liga o Lumen só nos níveis mais altos; nos de baixo, a luz indireta dinâmica cai para um método mais barato ou desaparece. Abra o arquivo da sua engine (`Engine/Config/BaseScalability.ini`) e leia a seção `[GlobalIlluminationQuality@1]`.

Se o seu Médio desliga o Lumen, o orçamento do Capítulo 58 foi medido num jogo que não é o que o Capítulo 51 iluminou. Jogue o setor 1 no Médio: a linguagem de luz (luz segura, luz que falha, escuridão) ainda se lê?

**Decisão para a Vigília:** o Médio da Vigília é definido pelo que a jogadora precisa ver, e não pelo nome que a engine dá ao nível. Se a luz deixar de se ler, copie as linhas de `[GlobalIlluminationQuality@2]` do `BaseScalability.ini` para um `[GlobalIlluminationQuality@1]` no `DefaultScalability.ini` do projeto, e pague o custo em outro grupo (sombras, pós-processo, resolução). O portão da seção 83.7 diz se coube.

---

## 83.2 Os piores casos do jogo inteiro

O Capítulo 58 listou quatro cenários, um deles "futuro". Com o jogo inteiro, a lista fica assim:

| Cenário (rótulo no relatório) | Onde | Por que é pior | O que o portão cobra |
|---|---|---|---|
| **Caçada no corredor** (`S1.Corredor.Cacada`) | `L_CasaDeForca`, `CP_S1_Corredor`, `VGPerfHunt` | Presença caçando, Diretor em `Peak`, cascata de luminárias, névoa, lanterna, áudio no máximo; o corredor agora em qualidade final (Cap. 78) | p95, p99, máximo |
| **Frame do checkpoint** (`S1.Subsolo.Checkpoint`) | `CP_S1_Subsolo`, `VGSave` no meio da captura | Narrativa, jogadora e mundo capturados num frame (Caps. 56–57) | máximo ≤ 16,7 |
| **Passagem fria** (`S1.Corredor.Cacada.Fria`, `S3.Galeria.Fria`) | A primeira caçada e a primeira vista do Salão no processo, com o cache de PSO do driver limpo | Materiais vistos pela primeira vez (seção 83.3) | máximo ≤ 33,3 |
| **Salão: a galeria** (`S3.Galeria`) | `L_Turbinas`, `CP_S3_Galeria` | A linha de visão mais longa do jogo: Lumen num espaço grande, malhas densas (Nanite condicionado, ADR-0011) | p95, p99, máximo |
| **Salão: a chegada ao poço** (`S3.Poco.Chegada`) | `CP_S3_Poco` | A carga de `L_Turbinas_Poco` por proximidade (ADR-0011) acontece com o jogo rodando | máximo ≤ 33,3 |
| **Salão: a perseguição** (`S3.Poco.Perseguicao`) | `CP_S3_Poco`, `VGPerfHunt` | A Presença na velocidade de caça, as luzes do poço falhando, as passarelas (Cap. 80) | p95, p99, máximo |
| **Subestação: os vigias** | `L_Subestacao` | Três vigias com utilidade e *tokens* (Cap. 80): o pior caso de IA no game thread | Fica para o Exercício (Parte 4) |

Cada cenário é um **ponto fixo**: um nível, um checkpoint (a posição e a rotação do `PlayerStart`, Cap. 56) e um comando que cria a situação. É o "reproduzir" do método do Capítulo 59, sem ninguém na frente do monitor. Como a IA não é determinística, os cenários quentes rodam **três vezes**.

A caçada no corredor continua na lista mesmo "resolvida" na Parte VIII: o Capítulo 60 otimizou o corredor de *grey-box*, e o do vertical slice tem outros materiais, outra névoa, outros sons. Um pior caso sai da lista quando o lugar deixa de existir, e não porque passou uma vez.

A perseguição é também o pior caso **de design**. Um *hitch* de 80 ms no instante em que a jogadora escolhe a curva da passarela tira dela o tempo de reação que as garantias de justiça do Capítulo 80 prometem.

---

## 83.3 A passagem fria: PSO

O Capítulo 59 achou a H3 (o PSO do material de dissolução da Presença), e o Capítulo 62 decidiu gravar um cache empacotado se o *hitch* frio passar de 33 ms. Com o jogo inteiro, a pergunta se repete em cada setor: o primeiro olhar para o Salão das Turbinas mostra dezenas de materiais novos.

As ferramentas da engine mudaram ao longo das versões 5.x, e o que segue é um mapa para ler a documentação da sua versão, e não uma receita (⚠️ confira cada nome):

- ***PSO precaching***: a engine tenta compilar os PSOs de que um componente vai precisar quando ele é **carregado**. Há uma CVar geral (`r.PSOPrecaching`) e uma família `r.PSOPrecache.*`.
- **Cache empacotado** (*bundled PSO cache*): você joga um build gravando os PSOs usados (parâmetro `-logPSO`), converte o registro com um *commandlet* (`ShaderPipelineCacheTools`) e inclui o resultado no próximo build, que compila esses PSOs na inicialização. A CVar `r.ShaderPipelineCache.Enabled` liga o mecanismo.
- **Cache do driver**: o driver de vídeo guarda o que já compilou, entre execuções. É por isso que a sua segunda execução não mostra o *hitch*, e a da jogadora mostra.

O *precaching* tem um custo que um jogo de terror sente mais. Compilar na carga alonga a carga (seção 83.6), e, ⚠️ conforme a versão e as CVars, a engine pode **adiar o desenho** de um objeto até o PSO dele ficar pronto, ou desenhá-lo com um material provisório. **[INFERÊNCIA]** Para a maioria dos objetos, aparecer um instante depois é invisível. Para a Presença, aparecer tarde ou com o material errado quebra a regra "nenhum ataque sem telegrafia" do Capítulo 80 de um jeito que nenhum teste de árvore de comportamento pega. O *hitch* é feio; a Presença invisível é injusta.

**Decisões para a Vigília:**

1. **O frio é medido sempre**, e não "quando der": o portão limpa o cache de PSO do driver antes de rodar (⚠️ o parâmetro `-clearPSODriverCache` existe em versões recentes; se não existir na sua, apague a pasta de cache do fabricante do driver antes da execução), e a primeira captura de cada setor tem o rótulo `.Fria`.
2. **A carga paga a compilação**: o nível troca atrás de um *fade* (Cap. 56), e é ali que a compilação deve acontecer. Se o frio estourar 33 ms, grave o cache empacotado com uma passagem completa pelo jogo (setores 1 a 3), não só pelo setor 1, como o Capítulo 62 previa.
3. **A Presença é verificada a olho** na passagem fria: grave a tela da primeira aparição dela em cada setor. O portão vê o frame, e não se ela chegou atrasada.

---

## 83.4 Escalabilidade: presets e grupos `sg.*`

No PC, a máquina da jogadora é desconhecida. A resposta da Unreal é a **escalabilidade**: o custo da renderização é dividido em grupos, cada grupo tem níveis de 0 a 4 (Baixo, Médio, Alto, Épico, Cinematográfico), e cada nível é uma lista de CVars de renderização. O "preset" que a jogadora escolhe no menu é só a mesma escolha para todos os grupos.

| Grupo | CVar | Onde pesa | Na Vigília |
|---|---|---|---|
| Resolução | `sg.ResolutionQuality` | GPU (porcentagem da tela; ⚠️ a escala não é 0–4) | Junto com o *upscaling* (Cap. 60) |
| Distância de visão | `sg.ViewDistanceQuality` | *Draw calls*, render thread, GPU | A galeria do Salão |
| *Anti-aliasing* | `sg.AntiAliasingQuality` | GPU | — |
| Sombras | `sg.ShadowQuality` | GPU e render thread | As luminárias com sombra (Cap. 60) |
| Iluminação global | `sg.GlobalIlluminationQuality` | GPU (Lumen) | A maior fatia; seção 83.1 |
| Reflexos | `sg.ReflectionQuality` | GPU (Lumen) | Metal das turbinas, poças |
| Pós-processo | `sg.PostProcessQuality` | GPU | Névoa, exposição (Cap. 51) |
| Texturas | `sg.TextureQuality` | **Memória de vídeo** (*streaming*) | Seção 83.5 |
| Efeitos | `sg.EffectsQuality` | GPU (translucidez, partículas) | Niagara (Cap. 54) |
⚠️ Há outros grupos (folhagem, *shading* e, em versões recentes, mais alguns); a lista completa está no `BaseScalability.ini`, em seções com o formato `[ShadowQuality@0]` a `[ShadowQuality@3]` e `[ShadowQuality@Cine]`. O projeto sobrescreve o que quiser num `Config/DefaultScalability.ini`, e a escolha da jogadora é gravada pelo `UGameUserSettings` (no caso da Vigília, `UVGGameUserSettings`, Cap. 55).

### O que a escalabilidade não escala

Repare na coluna "onde pesa": quase tudo é GPU, render thread e memória de vídeo. **O game thread não tem preset.** A Presença, o Diretor, as luminárias que piscam e a narrativa custam o mesmo no Baixo e no Épico, e o orçamento de CPU precisa caber no processador mais fraco que você aceita suportar. Por isso a máquina-alvo do Capítulo 58 é uma máquina inteira, e não uma placa de vídeo.

E algumas coisas **não podem** entrar num grupo de qualidade, porque comunicam regras. A telegrafia da Presença existe em todos os presets. Já o `vg.Fx.ImpactBudget` (Cap. 54, marcado com `ECVF_Scalability`) pode descer no Baixo: um impacto a menos não muda o que a jogadora sabe. O `vg.Flicker.Enabled` é acessibilidade (Cap. 55) e mora nas opções, não num preset. **O que comunica regra não escala.**

### O preset inicial por detecção

Na primeira execução, a jogadora ainda não escolheu nada. O `UGameUserSettings` oferece `RunHardwareBenchmark()`, um *benchmark* sintético curto de CPU e GPU, e `ApplyHardwareBenchmarkResults()`, que transforma os índices medidos em níveis por grupo usando limiares da própria engine (⚠️ a seção `[ScalabilitySettings]` do `BaseScalability.ini`, nas versões que a usam). O console tem o atalho `scalability auto` (⚠️ confira na sua versão).

Use com cautela. O *benchmark* é **genérico** (não conhece o Lumen do seu Salão), **curto** e portanto ruidoso (sobretudo num notebook na bateria), e os limiares da engine foram calibrados para um jogo médio, não para o seu orçamento. E, se rodar a cada inicialização, ele **apaga a escolha da jogadora**.

**Decisão para a Vigília:** o *benchmark* roda **uma vez**, atrás da tela de primeira execução (`WBP_PrimeiraVez`, Cap. 55), e o índice de GPU é comparado com o da **máquina-alvo**, onde o Médio foi validado: abaixo de 85% do alvo, Baixo; até 1,6 vez, Médio; acima, Alto. O Épico nunca é automático, porque ninguém o validou. Sem calibração, Médio. Depois, a qualidade é da jogadora.

---

## 83.5 Memória

São duas memórias, com dois orçamentos:

- a **RAM do processo**: objetos, malhas e animações carregadas, áudio, o próprio executável;
- a **memória de vídeo**: texturas (a maior parte), *buffers* de renderização, as estruturas do Lumen e do Nanite.

Estourar a primeira faz o sistema paginar (*hitches* longos e aleatórios) ou fechar o jogo. Estourar a segunda faz o *streaming* de texturas perder: texturas borradas que demoram a ficar nítidas.

As ferramentas, já listadas no Capítulo 59, ganham um papel cada:

| Ferramenta | Papel |
|---|---|
| `stat memory` | Triagem, jogando |
| `memreport -full` (⚠️ grava em `Saved/Profiling/MemReports/`) | Uma fotografia por nível: texturas, malhas, objetos por classe |
| `obj list class=<Classe>` | "Quantas `AVGLightFixture` estão vivas?" |
| LLM: `-llm`, `stat llm`, `stat llmfull` | "Quem está usando?", por categoria de sistema |
| Memory Insights (`-trace=memory`, ⚠️) | Vazamentos e picos na linha do tempo |
| `FPlatformMemory::GetStats()` | Memória residente do processo, em código: o portão (seção 83.7) |

Aqui, **LLM** é o *Low-Level Memory Tracker* da engine, um rastreador de alocações, e não um modelo de linguagem. Num livro com uma Parte sobre IA generativa, vale escrever o nome inteiro nos *prompts*.

⚠️ O LLM e o `memreport` podem não estar compilados no Test. Faça o diagnóstico detalhado num build **Development empacotado** (o editor distorce tudo) e deixe para o portão um número grosso e estável: a memória residente depois de assentar em cada nível.

### O orçamento de memória

**[DECISÃO DE PROJETO]**, e não medição: o processo usa no máximo **40% da RAM** da máquina-alvo, e as texturas do Médio cabem em **80% da memória de vídeo** dela; o resto é do sistema e dos programas que a jogadora deixa abertos. Com 16 GB, o teto é 6,4 GB; o `Tools/perf_budget.json` usa 6.000 MB como exemplo, e você troca pelo da sua máquina.

| Nível (modelo para preencher) | RAM residente | Pico do processo | Texturas (`memreport`) | Limite |
|---|---|---|---|---|
| `L_CasaDeForca` | | | | |
| `L_Subestacao` | | | | |
| `L_Turbinas` (com `L_Turbinas_Poco`) | | | | |
| `L_Final` | | | | |

Duas verificações baratas pegam os problemas mais comuns:

- **Vazamento entre níveis.** Abra o mesmo nível duas vezes e compare a memória residente. Se ela sobe a cada abertura, algo sobrevive à troca: um *delegate* estático, um ponteiro forte num subsistema da `GameInstance`.
- **O subnível que não sai.** Entre e saia do poço (`L_Turbinas_Poco`). A memória só volta quando a coleta de lixo roda (Cap. 58); se não voltar, procure quem ainda o referencia.

---

## 83.6 Tempos de carregamento

Para a jogadora, "carregamento" é o tempo entre o *fade* escurecer e o controle voltar, em três partes: o **`LoadMap`** (ler pak e IoStore, Cap. 62, e criar o mundo), a **restauração** (o `BeginPlay` e a persistência, Caps. 56–57) e o **"até jogável"** (texturas chegando pelo *streaming* e, com *precaching*, PSOs compilando: o jogo roda, mas ainda não está pronto para ser olhado).

Na Vigília, o carregamento acontece na troca de setor, no "Continuar" (reabrir o nível do save, Cap. 56), no subnível do poço (sem tela, com o jogo rodando) e, se o seu respawn reabre o nível pelo caminho do Capítulo 56, em **cada morte**. A última pesa mais: com a meta de 70% a 85% de sucesso na primeira tentativa da perseguição (Cap. 80), parte das jogadoras verá a carga do Salão duas ou três vezes seguidas, no momento de maior tensão.

**Orçamento [DECISÃO DE PROJETO]:** no máximo 20 segundos por troca de setor na máquina-alvo, medidos no primeiro carregamento do processo, e 10 para o `L_Final`, que é pequeno. O recarregamento depois de uma morte é medido à mão, morno, com meta de 8 segundos. O subnível do poço não tem orçamento de segundos: tem o de frame (nenhum frame acima de 33 ms durante a carga).

| Transição (modelo para preencher) | Primeiro carregamento | Depois de reiniciar o PC | Respawn | Limite |
|---|---|---|---|---|
| Pátio → `L_CasaDeForca` | | | | 20 s |
| → `L_Subestacao` | | | | 20 s |
| → `L_Turbinas` | | | | 20 s (respawn: 8 s) |
| → `L_Final` | | | | 10 s |

A coluna "depois de reiniciar" existe porque o sistema operacional guarda em memória os arquivos lidos recentemente: a segunda execução do portão lê o pak da RAM. Uma vez por milestone, meça depois de reiniciar a máquina; é o caso da jogadora que liga o computador para jogar.

---

## 83.7 O portão de performance

Um **portão** (*gate*) é uma verificação que bloqueia: se reprova, o build não segue. O da Vigília tem três peças, e duas delas já existiam:

1. **A rota**: os cenários da seção 83.2, percorridos sem ninguém no controle, com os cheats que o jogo já tem (`VGGotoCheckpoint`, `VGPerfHunt`, `VGPerfCapture`, `VGSave`, `VGGod`). Nenhum "modo de teste" entra nos sistemas (Cap. 59).
2. **O relatório**: uma linha por captura, no formato do Capítulo 58, com marcadores de cenário, de carga e de memória.
3. **O juiz**: um *script* fora do jogo, `Tools/perf_gate.py`, que lê o relatório, compara com `Tools/perf_budget.json` e devolve um código de saída. Zero, passou; diferente de zero, não passou.

O portão roda no build **Test**: o Development carrega *stats*, *checks* e logs que custam tempo, e o Shipping não tem cheats para dirigir a rota (Cap. 62). A diferença que sobra joga a favor da jogadora: o Shipping é um pouco mais rápido que o número medido. Ele roda na **máquina-alvo**, e não num servidor sem placa de vídeo, no build semanal (Cap. 79) e em cada candidato a release (Cap. 84); a rota leva minutos, e não cabe em cada *commit*.

Três regras fazem dele um portão, e não um enfeite:

- **Cenário ausente reprova.** Um checkpoint renomeado ou um cheat que mudou de nome não podem virar "passou" por falta de prova.
- **O pior frame não tem mediana.** Média, p95 e p99 usam a mediana das repetições; o máximo usa a pior. Uma travada em uma de três caçadas é uma travada que a jogadora vai ter.
- **Mudar o orçamento é uma decisão registrada.** Afrouxar um limite exige uma linha no `DEVLOG.md` com o motivo e o número medido. Sem isso, o orçamento vira o que o build de ontem conseguiu.

Duas execuções do mesmo build não dão o mesmo p95. Quando um cenário passa e falha alternadamente, encostado no limite, o portão não está quebrado: a folga acabou.

> 🌉 **Ponte:** é o *quality gate* do pipeline de integração contínua, ou o teste de carga com SLO que roda antes do deploy: o build só segue se as métricas couberem nos limites versionados no repositório.
>
> 🧱 **Onde a ponte cai:** o teste de carga roda em qualquer máquina do pipeline; este precisa de uma máquina **física específica**, com a placa de vídeo da jogadora, e não paraleliza. E ele reprova por mudanças que não são código: uma textura 4K esquecida numa parede reprova o build sem nenhuma linha de C++ alterada. O "teste" exercita a arte tanto quanto o programa.

---

## Estudos de caso

### Call of Duty: Modern Warfare (2019) e os *shaders* antes do jogo

**[FATO PÚBLICO, observável jogando]** Na versão de PC, o menu principal mostrava o progresso de uma etapa de "instalação de *shaders*" na primeira execução, e era possível entrar numa partida antes de ela terminar.

**[INFERÊNCIA]** A experiência protegida é o tiro competitivo a frame estável. A compilação antecipada acontece onde um *hitch* não custa nada (o menu); quem entra antes paga com travadas. É a troca da seção 83.3: mover a compilação para onde ela não é vista.

**Lição para a Vigília:** a carga atrás do *fade* é o "menu" da Vigília, e o portão mede o frio para saber se ela basta.

### GTA IV e GTA V no PC: a memória como orçamento visível

**[FATO PÚBLICO, observável jogando]** O menu de gráficos de *GTA V* no PC mostra uma barra de "memória de vídeo": quanto as opções escolhidas devem usar, contra o que a placa tem. O de *GTA IV* no PC limitava as opções pela memória de vídeo disponível, e jogadores contornavam o limite com o parâmetro de linha de comando `-norestrictions`.

**[INFERÊNCIA]** A barra é uma **estimativa** calculada a partir das opções, e não uma medição: ela transforma um orçamento técnico numa decisão que a jogadora entende. A trava do *GTA IV* mostra o outro lado: limite rígido demais, a jogadora desliga.

**Lição para a Vigília:** o orçamento de memória do Médio (seção 83.5) é medido, e não estimado; mostrá-lo nas opções seria legítimo, travá-las, não.

### PES 2011 e FIFA 14 no PS2: um hardware, um orçamento

**[FATO PÚBLICO]** O PlayStation 2 tem 32 MB de memória principal e 4 MB de memória de vídeo embutida no processador gráfico, e é igual em todas as casas. *PES 2011* e *FIFA 14* saíram para ele quando a geração seguinte já existia.

**[INFERÊNCIA]** Com um único hardware, o orçamento é uma constante, e o que a jogadora vê é o que o estúdio mediu. No PC, a máquina-alvo é um ponto numa distribuição, e a escalabilidade cuida do que está ao redor dele.

**Lição para a Vigília:** o portão garante o ponto (a máquina-alvo no Médio); a detecção e os presets, o resto. O game thread, que não escala, precisa caber no ponto mais fraco.

---

## Comparação com o desenvolvimento tradicional

| Conceito | O que você conhece | Onde a analogia cai |
|---|---|---|
| Portão de performance | *Quality gate* e teste de carga no pipeline | Exige uma máquina física específica; reprova por conteúdo, não só por código |
| p95/p99 do frame | Percentis de latência num SLO | O frame é prazo duro; um único pico importa (regra do máximo) |
| Passagem fria | *Cold start* de função *serverless*, aquecimento de JIT | O frio acontece na máquina da jogadora, uma vez por material, e o cache do driver esconde o problema de quem desenvolve |
| Presets de escalabilidade | Degradação graciosa, planos com recursos diferentes | O que comunica regra não pode degradar; o game thread não escala |
| Orçamento de memória | Limite de memória de contêiner | Não há reinício limpo: o sistema pagina, e o jogo trava |

---

## Unreal Engine: o que existe e o que não existe

**Existe:**

- medição: `stat unit`, `stat fps`, `startfpschart`/`stopfpschart`, CSV Profiler (`csvprofile start`/`stop`), Unreal Insights (Cap. 59);
- memória: `stat memory`, `memreport`, `obj list`, Low-Level Memory Tracker, Memory Insights, `FPlatformMemory::GetStats()`;
- escalabilidade: grupos `sg.*`, `BaseScalability.ini`/`DefaultScalability.ini`, `UGameUserSettings` (`SetOverallScalabilityLevel`, `RunHardwareBenchmark`, `GetLastGPUBenchmarkResult`);
- PSO: *precaching* e cache empacotado (⚠️ por versão);
- automação: `-ExecCmds` (comandos separados por vírgula), cheats (`UCheatManager`, presente no Test e ausente no Shipping), `FCoreUObjectDelegates::PreLoadMap`/`PostLoadMapWithWorld` e, no nível industrial, o **Gauntlet** e as **CSVTools** (como o `PerfReportTool`) (⚠️ confira a documentação da sua versão).

**Não existe:** o seu orçamento, a sua máquina-alvo e os seus piores casos; um portão que reprove um build por tempo de frame; um *benchmark* que conheça o seu jogo; a garantia de que o Médio da engine é o Médio de que o seu jogo precisa.

---

## Abordagens

| Critério | A. Medição manual com checklist | B. Rota no jogo + linhas `PERF` + juiz em Python | C. Gauntlet + CSV Profiler + PerfReportTool |
|---|---|---|---|
| Complexidade | Baixa | Média: um subsistema, um *script* | Alta: framework de automação em C# |
| Custo da medição | Nenhum | Nenhum além do `VGPerfCapture` | O CSV grava muito por frame |
| Extensibilidade | Depende de quem mede | Uma linha na rota, uma entrada no orçamento | Muito alta, várias máquinas e plataformas |
| Manutenção | Esquecimento garantido | Baixa; o formato é o do Cap. 58 | Alta para uma pessoa |
| Prototipação | Imediata | Uma tarde | Dias |
| Adequação à Vigília | Já existe (Cap. 59); não é portão | **Alta** | Excessiva para uma pessoa e uma máquina |

**Decisão:** B. O formato `PERF` é a moeda do projeto desde o Capítulo 58. Quando o portão reprova, o diagnóstico volta a ser A (o método do Cap. 59). C é o caminho se o jogo um dia tiver várias plataformas.

---

## Implementação

### 1. O subsistema do portão

O cheat manager morre com o `PlayerController` a cada `open`. Por isso a rota mora num subsistema da `GameInstance`, que sobrevive às trocas de nível, e anda no `FTSTicker`, com relógio real, como a captura do Capítulo 58.

```cpp
// Source/Vigilia/Debug/VGPerfGateSubsystem.h
#pragma once

#include "CoreMinimal.h"
#include "Containers/Ticker.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "VGPerfGateSubsystem.generated.h"

/**
 * Portão de performance (Cap. 83): percorre uma rota fixa e escreve linhas PERFSCENE, PERF, PERFLOAD
 * e PERFMEM em Saved/Profiling/VGPerf.log, que o Tools/perf_gate.py julga. Não existe em Shipping.
 */
UCLASS()
class VIGILIA_API UVGPerfGateSubsystem : public UGameInstanceSubsystem
{
    GENERATED_BODY()

public:
    virtual bool ShouldCreateSubsystem(UObject* Outer) const override { return !UE_BUILD_SHIPPING; }
    virtual void Deinitialize() override;

    /** Começa a rota (cheat VGPerfGate). Zera o relatório. */
    void Start();

    /** Uma linha no log e no relatório próprio, que existe mesmo se a configuração não tiver log. */
    static void Report(const FString& Line);
    static FString ReportPath();

private:
    bool Tick(float DeltaSeconds);
    void RunStep(const FString& Step);
    void HandlePreLoadMap(const FString& MapName);
    void HandlePostLoadMap(UWorld* LoadedWorld);

    FTSTicker::FDelegateHandle TickerHandle;
    int32 NextStep = 0;
    double ResumeAt = 0.0;      // relógio real: esperar não depende de pausa nem de dilatação
    double StepStartedAt = 0.0;
    double LoadStartedAt = 0.0;
    FString LoadingMap;
    bool bWaitingForMap = false;
};
```

```cpp
// Source/Vigilia/Debug/VGPerfGateSubsystem.cpp
#include "Debug/VGPerfGateSubsystem.h"

#include "Core/VGLog.h"
#include "Engine/GameInstance.h"
#include "Engine/World.h"
#include "GameFramework/PlayerController.h"
#include "HAL/FileManager.h"
#include "HAL/PlatformMemory.h"
#include "Misc/FileHelper.h"
#include "Misc/PackageName.h"
#include "Misc/Paths.h"
#include "UObject/UObjectGlobals.h"

namespace
{
    // Verbos do portão: "wait <s>", "scene <rótulo>", "mem". "open" espera o nível; o resto vai ao console.
    // Simplificação: a rota mora no código. Ela muda pouco, usa checkpoints versionados junto com os níveis
    // e não é cozida (um Data Asset em /Game/Vigilia/Data iria para o build de release, Cap. 62).
    const TCHAR* const GRoute[] =
    {
        TEXT("open L_CasaDeForca"), TEXT("wait 5"), TEXT("VGGod 1"), TEXT("mem"),       // vindo do Pátio
        TEXT("VGGotoCheckpoint CP_S1_Corredor"), TEXT("wait 3"),
        TEXT("scene S1.Corredor.Cacada.Fria"), TEXT("VGPerfHunt 20"), TEXT("wait 25"), // a primeira do processo
        TEXT("VGGotoCheckpoint CP_S1_Corredor"), TEXT("wait 3"),
        TEXT("scene S1.Corredor.Cacada"), TEXT("VGPerfHunt 20"), TEXT("wait 25"),
        TEXT("VGGotoCheckpoint CP_S1_Corredor"), TEXT("wait 3"),
        TEXT("scene S1.Corredor.Cacada"), TEXT("VGPerfHunt 20"), TEXT("wait 25"),
        TEXT("VGGotoCheckpoint CP_S1_Corredor"), TEXT("wait 3"),
        TEXT("scene S1.Corredor.Cacada"), TEXT("VGPerfHunt 20"), TEXT("wait 25"),
        TEXT("VGGotoCheckpoint CP_S1_Subsolo"), TEXT("wait 5"),
        TEXT("scene S1.Subsolo.Checkpoint"), TEXT("VGPerfCapture 4"), TEXT("wait 2"), TEXT("VGSave"), TEXT("wait 4"),
        TEXT("open L_Subestacao"), TEXT("wait 5"), TEXT("mem"),                         // vigias: Exercício
        TEXT("open L_Turbinas"), TEXT("wait 5"), TEXT("VGGod 1"), TEXT("mem"),
        TEXT("VGGotoCheckpoint CP_S3_Galeria"), TEXT("wait 3"),
        TEXT("scene S3.Galeria.Fria"), TEXT("VGPerfCapture 15"), TEXT("wait 17"),
        TEXT("scene S3.Galeria"), TEXT("VGPerfCapture 15"), TEXT("wait 17"),
        TEXT("scene S3.Galeria"), TEXT("VGPerfCapture 15"), TEXT("wait 17"),
        TEXT("scene S3.Galeria"), TEXT("VGPerfCapture 15"), TEXT("wait 17"),
        TEXT("VGGotoCheckpoint CP_S3_Poco"),                                             // dispara L_Turbinas_Poco
        TEXT("scene S3.Poco.Chegada"), TEXT("VGPerfCapture 8"), TEXT("wait 10"), TEXT("mem"),
        TEXT("scene S3.Poco.Perseguicao"), TEXT("VGPerfHunt 20"), TEXT("wait 25"),
        TEXT("VGGotoCheckpoint CP_S3_Poco"), TEXT("wait 3"),
        TEXT("scene S3.Poco.Perseguicao"), TEXT("VGPerfHunt 20"), TEXT("wait 25"),
        TEXT("VGGotoCheckpoint CP_S3_Poco"), TEXT("wait 3"),
        TEXT("scene S3.Poco.Perseguicao"), TEXT("VGPerfHunt 20"), TEXT("wait 25"),
        TEXT("open L_Final"), TEXT("wait 5"), TEXT("mem"),
        TEXT("quit"),
    };

    constexpr double MaxStepSeconds = 120.0; // um passo que não termina (nível que não carrega) aborta
}

FString UVGPerfGateSubsystem::ReportPath()
{
    return FPaths::ProfilingDir() / TEXT("VGPerf.log");
}

void UVGPerfGateSubsystem::Report(const FString& Line)
{
    UE_LOG(LogVigilia, Display, TEXT("%s"), *Line);
    // ⚠️ Conforme a versão e o alvo, o Test pode ser compilado sem log; este arquivo não depende disso.
    FFileHelper::SaveStringToFile(Line + LINE_TERMINATOR, *ReportPath(),
        FFileHelper::EEncodingOptions::ForceUTF8WithoutBOM, &IFileManager::Get(), FILEWRITE_Append);
}

void UVGPerfGateSubsystem::Start()
{
    if (TickerHandle.IsValid())
    {
        return; // já está rodando
    }
    IFileManager::Get().Delete(*ReportPath()); // um relatório por execução
    Report(FString::Printf(TEXT("PERFGATE início | relatório em %s"),
        *FPaths::ConvertRelativePathToFull(ReportPath())));
    FCoreUObjectDelegates::PreLoadMap.AddUObject(this, &UVGPerfGateSubsystem::HandlePreLoadMap);
    FCoreUObjectDelegates::PostLoadMapWithWorld.AddUObject(this, &UVGPerfGateSubsystem::HandlePostLoadMap);
    NextStep = 0;
    ResumeAt = 0.0;
    StepStartedAt = FPlatformTime::Seconds();
    TickerHandle = FTSTicker::GetCoreTicker().AddTicker(
        FTickerDelegate::CreateUObject(this, &UVGPerfGateSubsystem::Tick));
}

bool UVGPerfGateSubsystem::Tick(float /*DeltaSeconds*/)
{
    const double Now = FPlatformTime::Seconds();
    if (bWaitingForMap || Now < ResumeAt)
    {
        if (Now - StepStartedAt > MaxStepSeconds)
        {
            // O relatório fica incompleto, e o juiz reprova pelos cenários ausentes.
            Report(FString::Printf(TEXT("PERFGATE abortado no passo %d"), NextStep - 1));
            FPlatformMisc::RequestExit(false);
        }
        return true;
    }
    if (NextStep >= UE_ARRAY_COUNT(GRoute))
    {
        TickerHandle.Reset();
        return false; // só acontece se alguém tirar o "quit" da rota
    }
    StepStartedAt = Now;
    RunStep(GRoute[NextStep++]);
    return true;
}

void UVGPerfGateSubsystem::RunStep(const FString& Step)
{
    FString Verb = Step;
    FString Arg;
    Step.Split(TEXT(" "), &Verb, &Arg); // sem espaço, Verb continua sendo o passo inteiro
    UWorld* World = GetGameInstance()->GetWorld();

    if (Verb == TEXT("wait"))
    {
        ResumeAt = FPlatformTime::Seconds() + FCString::Atod(*Arg);
    }
    else if (Verb == TEXT("scene"))
    {
        Report(TEXT("PERFSCENE ") + Arg);
    }
    else if (Verb == TEXT("mem"))
    {
        const FPlatformMemoryStats Stats = FPlatformMemory::GetStats();
        Report(FString::Printf(TEXT("PERFMEM %s %.0f MB | pico do processo %.0f MB"), *World->GetMapName(),
            Stats.UsedPhysical / (1024.0 * 1024.0), Stats.PeakUsedPhysical / (1024.0 * 1024.0)));
    }
    else if (APlayerController* PC = GetGameInstance()->GetFirstLocalPlayerController(World))
    {
        bWaitingForMap = (Verb == TEXT("open")); // só o HandlePostLoadMap libera
        PC->ConsoleCommand(Step); // os cheats chegam ao UVGCheatManager por aqui
    }
    else
    {
        Report(TEXT("PERFGATE sem controller para: ") + Step);
    }
}

void UVGPerfGateSubsystem::HandlePreLoadMap(const FString& MapName)
{
    LoadingMap = FPackageName::GetShortName(MapName);
    LoadStartedAt = FPlatformTime::Seconds();
}

void UVGPerfGateSubsystem::HandlePostLoadMap(UWorld* /*LoadedWorld*/)
{
    // Simplificação: mede o LoadMap, e não o "até jogável" (seção 83.6). O streaming de texturas e os PSOs
    // que continuam depois caem na espera seguinte da rota e na primeira captura ".Fria".
    Report(FString::Printf(TEXT("PERFLOAD %s %.2f s"), *LoadingMap, FPlatformTime::Seconds() - LoadStartedAt));
    bWaitingForMap = false;
}

void UVGPerfGateSubsystem::Deinitialize()
{
    FCoreUObjectDelegates::PreLoadMap.RemoveAll(this);
    FCoreUObjectDelegates::PostLoadMapWithWorld.RemoveAll(this);
    if (TickerHandle.IsValid())
    {
        FTSTicker::GetCoreTicker().RemoveTicker(TickerHandle);
    }
    Super::Deinitialize();
}
```

### 2. 🔁 A captura escreve no relatório, e o cheat que liga a rota

**Antes** (Cap. 58), o `VGPerfCapture` terminava num `UE_LOG`. **O problema:** o log pode não existir no Test. **Agora**, a mesma linha, no **mesmo formato**, passa pelo `Report`, que escreve no log e no arquivo; as linhas antigas do `DEVLOG.md` continuam legíveis pelo juiz.

```cpp
// UVGCheatManager.cpp (🔁 no fim do ticker do VGPerfCapture, Cap. 58)
#include "Debug/VGPerfGateSubsystem.h"

        UVGPerfGateSubsystem::Report(FString::Printf(
            TEXT("PERF %d frames | média %.2f ms | p95 %.2f | p99 %.2f | máx %.2f | acima de %.2f ms: %d (%.1f%%), mais limitados por %s"),
            Capture->Frames.Num(), Sum / Capture->Frames.Num(),
            VGPerfRules::Percentile(Capture->Frames, 95.0f), VGPerfRules::Percentile(Capture->Frames, 99.0f),
            VGPerfRules::Percentile(Capture->Frames, 100.0f), Capture->BudgetMs,
            Over, 100.0f * Over / Capture->Frames.Num(), VGPerfRules::ToString(Worst)));
```

```cpp
// UVGCheatManager (adição)
UFUNCTION(Exec) void VGPerfGate();

// UVGCheatManager.cpp (adição)
void UVGCheatManager::VGPerfGate()
{
    if (UVGPerfGateSubsystem* Gate = UGameInstance::GetSubsystem<UVGPerfGateSubsystem>(GetWorld()->GetGameInstance()))
    {
        UE_LOG(LogVigilia, Display, TEXT("Cheat: VGPerfGate"));
        Gate->Start();
    }
}
```

### 3. O preset inicial

A regra é pura e mora em `Core/`, ao lado de quem a usa (`UVGGameUserSettings`). Em `Debug/`, ela criaria uma dependência `Core → Debug` que o verificador de camadas do Capítulo 77 recusaria.

```cpp
// Source/Vigilia/Core/VGQualityRules.h
#pragma once

#include "CoreMinimal.h"

namespace VGQualityRules
{
    /**
     * Preset proposto (0 Baixo, 1 Médio, 2 Alto) pelo índice de GPU do benchmark da engine, relativo ao da
     * máquina-alvo, onde o Médio foi validado (Cap. 58). O Épico nunca é automático.
     */
    inline int32 QualityForGpuIndex(float GpuIndex, float TargetGpuIndex)
    {
        if (GpuIndex <= 0.0f || TargetGpuIndex <= 0.0f)
        {
            return 1; // sem medida ou sem calibração: o preset validado
        }
        const float Ratio = GpuIndex / TargetGpuIndex;
        // Simplificação: dois limiares fixos e conservadores; o portão mede o Médio, e não o Alto.
        return Ratio < 0.85f ? 0 : (Ratio < 1.6f ? 1 : 2);
    }
}
```

```cpp
// UVGGameUserSettings (🔁 adição ao Cap. 55)
UPROPERTY(Config)
bool bQualityDetected = false; // depois da primeira detecção, a qualidade é da jogadora

/** Chamado pelo menu principal antes da WBP_PrimeiraVez. */
void DetectQualityOnce();

// VGGameUserSettings.cpp (adição)
#include "Core/VGQualityRules.h"

// Índice de GPU do benchmark na máquina-alvo (docs/tech/maquina-alvo.md). 0 = não calibrado: tudo vira Médio.
static constexpr float TargetMachineGpuIndex = 0.0f;

void UVGGameUserSettings::DetectQualityOnce()
{
    if (bQualityDetected)
    {
        return;
    }
    RunHardwareBenchmark(); // ⚠️ síncrono e sintético: rode atrás de uma tela, nunca durante o jogo
    const int32 Level = VGQualityRules::QualityForGpuIndex(GetLastGPUBenchmarkResult(), TargetMachineGpuIndex);
    UE_LOG(LogVigilia, Display, TEXT("Qualidade: índice de GPU %.1f (alvo %.1f) -> nível %d"),
        GetLastGPUBenchmarkResult(), TargetMachineGpuIndex, Level);
    SetOverallScalabilityLevel(Level);
    bQualityDetected = true;
    ApplySettings(false);
    SaveSettings();
}
```

Para calibrar, rode o jogo uma vez na máquina-alvo, copie o índice da linha `Qualidade:` do log para `TargetMachineGpuIndex` e anote-o em `docs/tech/maquina-alvo.md`.

```cpp
// Source/Vigilia/Tests/VGQualityRulesTest.cpp
#include "Misc/AutomationTest.h"
#include "Core/VGQualityRules.h"

#if WITH_DEV_AUTOMATION_TESTS

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FVGQualityRulesTest, "Vigilia.Perf.Quality.FromGpuIndex",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ProductFilter)

bool FVGQualityRulesTest::RunTest(const FString& Parameters)
{
    TestEqual(TEXT("Sem calibração: Médio"), VGQualityRules::QualityForGpuIndex(250.0f, 0.0f), 1);
    TestEqual(TEXT("Metade do alvo: Baixo"), VGQualityRules::QualityForGpuIndex(50.0f, 100.0f), 0);
    TestEqual(TEXT("O alvo: Médio"), VGQualityRules::QualityForGpuIndex(100.0f, 100.0f), 1);
    TestEqual(TEXT("Dez vezes o alvo: Alto, nunca Épico"), VGQualityRules::QualityForGpuIndex(1000.0f, 100.0f), 2);
    return true;
}

#endif
```

### 4. Uma CVar do jogo num grupo de qualidade

```ini
; Config/DefaultScalability.ini — só o que a Vigília muda nos grupos da engine (Cap. 83).
; @0 Baixo, @1 Médio, @2 Alto, @3 Épico, @Cine Cinematográfico (⚠️ confira os nomes no BaseScalability.ini).
; O Médio mantém o valor do Cap. 54, que foi o medido.
[EffectsQuality@0]
vg.Fx.ImpactBudget=3

[EffectsQuality@1]
vg.Fx.ImpactBudget=8

[EffectsQuality@2]
vg.Fx.ImpactBudget=12

[EffectsQuality@3]
vg.Fx.ImpactBudget=16

[EffectsQuality@Cine]
vg.Fx.ImpactBudget=16
```

### 5. O orçamento

```json
{
  "_leia": "Limites do portão (Cap. 83), derivados do orçamento do Cap. 58. Não são medições. ms por cenário: avg/p95/p99 pela mediana das repetições, max pela pior. Mudar um limite exige uma linha no DEVLOG.md com o motivo.",
  "scenarios": {
    "S1.Corredor.Cacada.Fria": {"max": 33.3},
    "S1.Corredor.Cacada": {"p95": 14.0, "p99": 16.7, "max": 33.3},
    "S1.Subsolo.Checkpoint": {"max": 16.7},
    "S3.Galeria.Fria": {"max": 33.3},
    "S3.Galeria": {"p95": 14.0, "p99": 16.7, "max": 33.3},
    "S3.Poco.Chegada": {"max": 33.3},
    "S3.Poco.Perseguicao": {"p95": 14.0, "p99": 16.7, "max": 33.3}
  },
  "load_s": {"L_CasaDeForca": 20, "L_Subestacao": 20, "L_Turbinas": 20, "L_Final": 10},
  "memory_mb": {"L_CasaDeForca": 6000, "L_Subestacao": 6000, "L_Turbinas": 6000, "L_Final": 6000}
}
```

### 6. O juiz

```python
#!/usr/bin/env python3
"""Portão de performance da Vigília (Cap. 83).
Uso: python Tools/perf_gate.py <VGPerf.log> [Tools/perf_budget.json]  -> código de saída 1 se estourar ou faltar."""
import json
import re
import statistics
import sys
from pathlib import Path

SCENE = re.compile(r"PERFSCENE (\S+)")
# Linha do Cap. 58: "PERF 1200 frames | média 12.34 ms | p95 13.10 | p99 15.20 | máx 31.00 | acima de ...".
# As palavras acentuadas viram \S+: o parser não depende da codificação do arquivo.
PERF = re.compile(r"PERF \d+ frames \| \S+ ([\d.]+) ms \| p95 ([\d.]+) \| p99 ([\d.]+) \| \S+ ([\d.]+)")
LOAD = re.compile(r"PERFLOAD (\S+) ([\d.]+) s")
MEM = re.compile(r"PERFMEM (\S+) ([\d.]+) MB")
METRICS = ("avg", "p95", "p99", "max")


def parse(lines):
    """Cenário -> métrica -> valores; nível -> segundos de carga; nível -> MB residentes."""
    perf, loads, mem, scene = {}, {}, {}, None
    for line in lines:
        if m := SCENE.search(line):
            scene = m[1]
        elif m := PERF.search(line):
            metrics = perf.setdefault(scene or "?", {})
            for name, value in zip(METRICS, m.groups()):
                metrics.setdefault(name, []).append(float(value))
            scene = None  # um marcador vale para uma captura
        elif m := LOAD.search(line):
            loads.setdefault(m[1], []).append(float(m[2]))
        elif m := MEM.search(line):
            mem.setdefault(m[1], []).append(float(m[2]))
    return perf, loads, mem


def aggregate(metric, values):
    """Tendência pela mediana das repetições; o pior frame não tem mediana."""
    return max(values) if metric == "max" else statistics.median(values)


def judge(perf, loads, mem, budget):
    """Problemas encontrados (lista vazia = passou). Cenário ausente é falha, não silêncio."""
    problems = []
    for scene, limits in budget.get("scenarios", {}).items():
        if scene not in perf:
            problems.append(f"{scene}: ausente (a rota chegou lá?)")
            continue
        for metric, limit in limits.items():
            value = aggregate(metric, perf[scene][metric])
            if value > limit:
                problems.append(f"{scene}: {metric} {value:.2f} ms > {limit:.2f} ms")
    for section, data, unit in (("load_s", loads, "s"), ("memory_mb", mem, "MB")):
        for name, limit in budget.get(section, {}).items():
            if name not in data:
                problems.append(f"{name}: {section} ausente")
            elif max(data[name]) > limit:
                problems.append(f"{name}: {section} {max(data[name]):.1f} {unit} > {limit} {unit}")
    return problems


def _self_test():
    log = [
        "[2026.11.12-21.00.00:000][  0]LogVigilia: Display: PERFSCENE S1.Corredor.Cacada",
        "LogVigilia: Display: PERF 1200 frames | média 12.00 ms | p95 13.00 | p99 15.00 | máx 20.00"
        " | acima de 16.67 ms: 3 (0.3%), mais limitados por GPU",
        "PERFSCENE S1.Corredor.Cacada",
        "PERF 1180 frames | m�dia 12.50 ms | p95 14.50 | p99 16.00 | m�x 22.00"
        " | acima de 16.67 ms: 5 (0.4%), mais limitados por GPU",
        "PERFSCENE S1.Corredor.Cacada",
        "PERF 1150 frames | média 13.00 ms | p95 15.00 | p99 17.00 | máx 40.00"
        " | acima de 16.67 ms: 9 (0.8%), mais limitados por GPU",
        "PERFLOAD L_Turbinas 7.50 s",
        "PERFMEM L_Turbinas 3100 MB | pico do processo 3300 MB",
    ]
    perf, loads, mem = parse(log)
    assert perf["S1.Corredor.Cacada"]["p95"] == [13.0, 14.5, 15.0], perf
    ok = {"scenarios": {"S1.Corredor.Cacada": {"p95": 14.5, "max": 40.0}},
          "load_s": {"L_Turbinas": 8}, "memory_mb": {"L_Turbinas": 3500}}
    assert judge(perf, loads, mem, ok) == [], judge(perf, loads, mem, ok)
    bad = {"scenarios": {"S1.Corredor.Cacada": {"max": 33.3}, "S3.Galeria": {"p99": 16.7}},
           "load_s": {"L_Turbinas": 6}}
    problems = judge(perf, loads, mem, bad)
    # o pior frame (40) reprova mesmo com mediana 22; o cenário ausente e a carga também
    assert len(problems) == 3 and "max 40.00" in problems[0] and "ausente" in problems[1], problems


if __name__ == "__main__":
    _self_test()
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    text = Path(sys.argv[1]).read_text(encoding="utf-8-sig", errors="replace")
    budget_path = Path(sys.argv[2] if len(sys.argv) > 2 else "Tools/perf_budget.json")
    budget = json.loads(budget_path.read_text(encoding="utf-8"))
    perf, loads, mem = parse(text.splitlines())
    for scene, metrics in sorted(perf.items()):
        print(f"{scene} (n={len(metrics['max'])}): "
              + " | ".join(f"{k} {aggregate(k, v):.2f}" for k, v in metrics.items()))
    for name in sorted(set(loads) | set(mem)):
        print(f"{name}: carga {max(loads.get(name, [0])):.1f} s | memória {max(mem.get(name, [0])):.0f} MB")
    problems = judge(perf, loads, mem, budget)
    print("\n".join(problems) or "Orçamento OK.")
    sys.exit(1 if problems else 0)
```

### 7. A execução

```bat
@echo off
rem Tools/PerfGate.bat — o portão no build Test (Cap. 83). Antes: Tools\BuildVigilia.bat Test (Cap. 62).
setlocal
set ROOT=%~dp0..
set PKG=%ROOT%\Builds\Test\Windows\Vigilia
rem ⚠️ O executável na raiz do pacote é um lançador; chamamos o binário do jogo, que o cmd espera terminar.
rem ⚠️ Confira os dois caminhos no seu build; a linha "PERFGATE início" do relatório mostra o segundo.
set GAME=%PKG%\Binaries\Win64\Vigilia-Win64-Test.exe
set REPORT=%PKG%\Saved\Profiling\VGPerf.log

rem Cache de PSO do driver limpo: as capturas ".Fria" são frias de verdade (⚠️ parâmetro por versão).
"%GAME%" L_Patio -ResX=1920 -ResY=1080 -windowed -clearPSODriverCache ^
    -ExecCmds="r.VSync 0,t.MaxFPS 0,scalability 1,VGPerfGate"

python "%ROOT%\Tools\perf_gate.py" "%REPORT%" "%ROOT%\Tools\perf_budget.json"
exit /b %errorlevel%
```

### Explicação das decisões

- **A rota usa os cheats, e o portão não toca nos sistemas.** Nenhuma classe de IA, luz ou save sabe que está sendo medida.
- **Começa no Pátio.** A primeira carga medida é a transição que a jogadora faz, e o Pátio tem o `PlayerController` com cheats; o menu principal pode não ter.
- **O formato da linha `PERF` não mudou**, e os rótulos vêm em linhas `PERFSCENE` separadas. O juiz lê o relatório, o log da engine e as linhas antigas do `DEVLOG.md`; as palavras acentuadas viram `\S+`, para que outra codificação não reprove o build por um "é".
- **`-ExecCmds` fixa as condições de medida.** VSync e limite de FPS desligados (Cap. 58), preset Médio por console, para que o resultado não dependa do que estiver gravado no `GameUserSettings.ini` daquela máquina.
- **`VGGod 1` depois de cada `open`.** Uma morte no meio da rota reabriria o nível e misturaria uma carga com uma captura.
- **Abortar em vez de travar.** Com o limite de 120 s por passo, um nível que não carrega encerra o processo, e o juiz reprova pelos cenários que faltaram.

---

## Projeto Final — o portão de performance da Vigília

1. **Calibre.** Confira o Médio (seção 83.1), meça o índice de GPU da máquina-alvo e escreva-o em `TargetMachineGpuIndex` e em `docs/tech/maquina-alvo.md`.
2. **Rode** `Tools\BuildVigilia.bat Test` e `Tools\PerfGate.bat` na máquina-alvo, com o resto dos programas fechados.
3. **Leia.** A primeira execução quase certamente reprova algo. Uma saída possível, só para mostrar a leitura:

```text
[HIPOTÉTICO — saída ilustrativa, não medida]
S1.Corredor.Cacada (n=3): avg 11.80 | p95 13.20 | p99 15.40 | max 24.10
S1.Corredor.Cacada.Fria (n=1): avg 12.40 | p95 14.10 | p99 20.90 | max 41.70
S3.Galeria (n=3): avg 13.90 | p95 15.60 | p99 16.40 | max 22.30
S1.Corredor.Cacada.Fria: max 41.70 ms > 33.30 ms
S3.Galeria: p95 15.60 ms > 14.00 ms
```

   O frio estourou e o quente passou: é PSO, e o Capítulo 62 já diz o que fazer (cache empacotado, agora com os três setores). A galeria falha no p95 sem *hitch*: o frame inteiro está pesado. Se a linha `PERF` apontar a GPU, o Insights (Cap. 59) diz quanto é Lumen; com *draw calls* sob controle, o HLOD segue desnecessário e o ADR-0011 se mantém.
4. **Corrija pelo método.** Uma hipótese escrita, uma mudança, o portão de novo (Cap. 59). Cada rodada vira uma linha no `DEVLOG.md`.
5. **Registre.** 🔁 `docs/tech/orcamento.md` ganha a tabela de tradução da seção 83.1 e o rótulo "revisto no Cap. 83". O risco "Performance no Salão das Turbinas" (Cap. 76) passa a ter gatilho verificável: qualquer reprovação de `S3.*`. E o Capítulo 84 usa o portão como critério do build de release.

| Execução (modelo para o `DEVLOG.md`) | Data | Build | Máquina | Preset | Reprovações | Mudança feita |
|---|---|---|---|---|---|---|
| 1 | | | | Médio | | — |
| 2 | | | | Médio | | |

---

## Decisões arquiteturais

1. **O portão verifica o frame; as fatias por sistema servem ao diagnóstico** (seção 83.1).
2. **Piores casos são pontos fixos**, com três repetições quentes e uma captura fria por setor.
3. **Cenário ausente reprova; o máximo usa a pior repetição; mudar um limite exige registro** (seção 83.7).
4. **Build Test, máquina-alvo, build semanal e candidatos a release.**
5. **O Médio da Vigília é definido pela leitura da luz.**
6. **O que comunica regra não escala.**
7. **Detecção uma vez, relativa à máquina-alvo, nunca Épico.**

---

## Armadilhas

- **Medir com o cache quente e chamar de frio.** O cache do driver sobrevive entre execuções.
- **Medir num notebook na bateria**, ou depois de horas de compilação com o processador quente.
- **Comparar execuções com resoluções ou modos de janela diferentes.** Fixe-os no `PerfGate.bat` e nunca mude sem registrar.
- **Teleporte que pula o gatilho de *streaming*.** Se a carga do poço depende de um volume que o `VGGotoCheckpoint` não atravessa, a captura mede um poço que não existe (⚠️ o `UCheatManager` tem `StreamLevelIn` para forçar a carga).
- **Escalar o que comunica.** Um Baixo sem a telegrafia da Presença é um jogo diferente, e injusto.
- **Pedir ajuda sobre "LLM" sem dizer qual.** O Low-Level Memory Tracker não é um modelo de linguagem.

---

## Exercício

**Parte 1 — a rota e o relatório (2 h).** Implemente o `UVGPerfGateSubsystem`, o 🔁 do `VGPerfCapture` e o `VGPerfGate`. Rode em *Standalone* com uma rota curta (um cenário) e confira o `VGPerf.log`.

**Parte 2 — o juiz (1 h).** Coloque `Tools/perf_gate.py` e `Tools/perf_budget.json` no projeto. Rode o *script* sobre as linhas `PERF` antigas do seu `DEVLOG.md` e sobre um orçamento que você sabe que reprova: o código de saída tem de ser 1.

**Parte 3 — a primeira execução real (1,5 h).** Rode `PerfGate.bat` duas vezes na máquina-alvo, preencha as tabelas das seções 83.5, 83.6 e do Projeto Final, e anote quanto o p95 variou entre as duas.

**Parte 4 — o setor 2 (1 h).** Acrescente à rota o encontro dos vigias da Subestação (um checkpoint antes do encontro, `VGAlertHeat` ou o caminho que dispara o encontro no seu jogo, três repetições) e a entrada no orçamento.

---

## Desafio — regressão, não só orçamento

Um cenário pode piorar 3 ms e ainda passar. Faça o `perf_gate.py` gravar as medianas num `Builds/perf_last.json` e, na execução seguinte, avisar (sem reprovar) qualquer métrica que piorou mais de 10% ou de 1 ms: é a "comparação automática" que o Capítulo 59 deixou como desafio. A partir de quanto o aviso vira reprovação? Justifique.

---

## Uso de IA

1. **Para conferir a escalabilidade da sua versão:**
   > "Vou colar a seção `[GlobalIlluminationQuality@1]` e a `[GlobalIlluminationQuality@2]` do `BaseScalability.ini` da minha Unreal 5.x. Explique linha por linha o que cada CVar faz e se o Lumen fica ligado em cada nível. Não complete com conhecimento de outras versões: se uma CVar não estiver no texto, diga que não está. [seções]"

2. **Para estender o juiz:**
   > "Este é o meu `perf_gate.py` [código]. Acrescente o aviso de regressão do Desafio, só com a biblioteca padrão, e estenda o `_self_test` com um caso que piora 12% e outro que piora 5%. Mostre os asserts antes da implementação."

3. **Para ler uma reprovação:**
   > "O meu portão reprovou assim [saída], com a linha `PERF` dizendo 'mais limitados por GPU'. Proponha três hipóteses na ordem do ataque do Capítulo 60 (não fazer, menos vezes, menos coisas, mais barato), cada uma com a medida no Unreal Insights que a confirma ou derruba."

**Cuidado específico:** nomes de CVars de PSO, de escalabilidade e de memória mudaram ao longo do UE5, e a IA mistura versões com segurança total. Toda CVar sugerida precisa ser encontrada no código ou nos `.ini` da **sua** engine (`Engine/Config`, ou `help` no console) antes de entrar no `DefaultScalability.ini`. E números de performance vindos de uma IA são sempre inventados: o único número válido é o do seu portão.

---

## Checklist

- [ ] O Médio da Vigília conferido no `BaseScalability.ini`, e a leitura da luz testada nele.
- [ ] `UVGPerfGateSubsystem`, `VGPerfGate` e o 🔁 do `VGPerfCapture` com `Report`.
- [ ] `Tools/perf_gate.py` com `_self_test` passando e `Tools/perf_budget.json` versionados.
- [ ] `Tools/PerfGate.bat` rodado na máquina-alvo, com o cache de PSO limpo.
- [ ] Tabelas de memória e de carga preenchidas, uma delas depois de reiniciar o PC.
- [ ] `DetectQualityOnce` calibrado com o índice da máquina-alvo; teste `Vigilia.Perf.Quality.FromGpuIndex` passando.
- [ ] `docs/tech/orcamento.md` revisto e o risco do Salão das Turbinas com gatilho no portão.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation): *Scalability Reference*, as páginas de *PSO Precaching* e de cache de PSO, *Low-Level Memory Tracker*, *Memory Insights*, *CSV Profiler* e *Gauntlet Automation Framework* (confira os títulos na sua versão).
- **`Engine/Config/BaseScalability.ini`** da sua instalação: a fonte de verdade sobre o que cada preset faz.
- **Digital Foundry** (site e canal): análises de tempo de frame e de *stutter* de compilação de *shaders* em lançamentos de PC.
- **Jason Gregory, *Game Engine Architecture***: os capítulos sobre o *game loop*, memória e ferramentas de *profiling*.
- **Steam Hardware & Software Survey** (store.steampowered.com/hwsurvey): a distribuição em volta da sua máquina-alvo.

---

➡️ **Próximo:** [Capítulo 84 — Build](cap-84-build.md)
