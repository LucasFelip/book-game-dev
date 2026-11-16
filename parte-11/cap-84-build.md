# Capítulo 84 — Build

## Objetivo

Ao final deste capítulo você deve conseguir:

- levar a Vigília à versão **1.0.0**, promovendo o candidato aprovado sem recompilar;
- manter um **histórico de builds** e arquivar o build com os símbolos e o `DEVLOG.md`;
- percorrer um **checklist de release** verificável: máquina limpa, licenças, créditos, versão, símbolos, performance, camadas e testes;
- provar que a **IA generativa ficou fora** (ADR-0010) e que o jogo funciona sem rede;
- preparar a **distribuição** sem depender dos detalhes de uma loja;
- conduzir o experimento **`exp/coop-s1`**: espelho dos fatos, narrativa em modo réplica, rádio no servidor, lanterna como pedido;
- registrar um **inventário de quebras** e tirar do experimento a lição de arquitetura que a spec pede.

---

## Contexto

O Capítulo 76 deu ao Milestone 10 (*Release Build*) o objetivo "um executável que outra pessoa roda" e o critério: o build roda numa máquina limpa, e o *postmortem* (Cap. 85) está escrito.

Quase nada aqui é novo. O Capítulo 62 montou o *pipeline* e gerou o `0.8.0`, "a primeira linha de uma série que vai continuar até o Capítulo 84". Depois vieram o `Tools/check_layers.py` (Cap. 77), o portão de performance (Cap. 83), o ADR-0010 e o desenho cooperativo (Interlúdio III). O trabalho agora é **juntar e verificar**.

São duas entregas opostas. O **release** é conservador: só verificar, corrigir bugs de classe A (Cap. 79) e congelar. O **experimento cooperativo** é exploratório: quebrar de propósito e entender por quê. Primeiro o release, depois o experimento, num ramo que nasce da *tag* do release, como manda o ADR-0012.

---

## 84.1 Do candidato ao release

Depois do Milestone 9, o projeto **congela**: só bugs de classe A entram. Um bug B descoberto agora vai para o `DEVLOG.md` com a decisão "fica para o 1.0.1".

Um **candidato** é um build gerado pelo *script*, a partir de um *commit* limpo, que passa **inteiro** pelo checklist da seção 84.3 ou é descartado. Cada correção de um bug A é um *commit* novo e um candidato novo.

Quando um candidato passa, ele **é** o release. Não se recompila "o mesmo *commit*" para a versão final, por dois motivos:

- **Os símbolos não batem.** Cada *link* gera um `.pdb` com identidade própria, e o *debugger* só lê um *crash* com o `.pdb` do binário exato que travou (Cap. 61).
- **O que foi testado é o que vai.** Recompilar reabre a porta para uma configuração local, uma ferramenta atualizada, um arquivo que mudou no meio.

Por isso `ProjectVersion=1.0.0` é fixada **antes** do primeiro candidato, e os candidatos se distinguem pelo *commit*; o aprovado recebe a *tag* `v1.0.0`.

São dois números com contratos diferentes. `ProjectVersion` (menu, campo `BuildVersion` do save) é o contrato com a jogadora e com o diagnóstico de bugs, e muda a cada build publicado; segue a ideia do *Semantic Versioning*, adaptada (1.0.0 é a primeira versão pública; o segundo número, conteúdo; o terceiro, correções). `SaveVersion` (Cap. 56) é o contrato com os arquivos no disco dela, e só muda quando o **significado** do save muda, com migração.

> 🌉 **Ponte:** é o *release candidate* e o "*build once, deploy many*" da entrega contínua.
>
> 🧱 **Onde a ponte cai:** o *deploy* vai para máquinas que você nunca verá, e o *rollback* é a jogadora baixar outra versão. Um save do 1.0.1 aberto no 1.0.0 é recusado ("do futuro, nunca adivinhar", Cap. 56): as migrações rodam no disco dela.

---

## 84.2 O histórico de builds e o arquivo

O Capítulo 85 cita como fonte o histórico de builds: `docs/release/builds.csv`, versionado, uma linha por candidato. O *script* escreve as colunas mecânicas; você, o resultado:

```text
data,versao,config,commit,tamanho_mb,resultado,notas
AAAA-MM-DD,1.0.0,Test,4f1c2a9,[SEU NÚMERO],aprovado,PerfGate.bat: saída 0 na máquina-alvo
AAAA-MM-DD,1.0.0,Shipping,4f1c2a9,[SEU NÚMERO],reprovado,máquina limpa: crash no L_Final (bug A)
```

As linhas são um exemplo de formato [HIPOTÉTICO]. Quantos candidatos o release custou é um dos números mais honestos do *postmortem*.

O release é tudo de que você vai precisar para entender, daqui a dois anos, um *crash* que alguém lhe mandar:

```text
Release/1.0.0/          fora do repositório, e uma segunda cópia em outro disco
  Game/                 o build Shipping, exatamente o que foi testado
  Symbols/              os .pdb DO MESMO build (Cap. 61)
  TestReport/           o relatório dos testes de automação daquele commit
  perf/                 o VGPerf.log do build Test e a saída do PerfGate.bat (Cap. 83)
  DEVLOG.md             o diário até o release (o Cap. 85 lê daqui)
  builds.csv            o histórico até o release
  THIRD_PARTY.md        as licenças, como estavam no release
  ENGINE.txt            versão exata da engine, do Visual Studio e do Windows SDK
```

O `ENGINE.txt` guarda o que o `.uproject` não guarda (compilador, SDK). O `DEVLOG.md` entra na **promoção**, depois do resultado da máquina limpa.

---

## 84.3 O checklist de release

A lista da máquina limpa do Capítulo 62 tinha oito itens, para o setor 1. A do release cobre o jogo inteiro e o que vem antes do build:

| # | Item | Como verificar | Quem |
|---|---|---|---|
| 1 | Camadas | `Tools/check_layers.py` sem violação (Cap. 77) | *Script* |
| 2 | Testes | Todos os `Vigilia.*` verdes | *Script* |
| 3 | Performance | `Tools\PerfGate.bat`, depois de `Tools\BuildVigilia.bat Test` do **mesmo *commit***, na máquina-alvo, sai com 0: o `Tools/perf_gate.py` aprovou o `Saved/Profiling/VGPerf.log` contra o `Tools/perf_budget.json` (Cap. 83) | *Script* |
| 4 | Bugs | Nenhum A aberto; os B conhecidos no `DEVLOG.md` | Você |
| 5 | Versão e origem | `ProjectVersion=1.0.0`; árvore limpa; *commit* no histórico | `release.py` |
| 6 | Mapas | Os seis níveis e o subnível do poço na lista; nada de `/Game/Developers` | Teste |
| 7 | Símbolos | `.pdb` arquivados com o build | *Script* |
| 8 | IA generativa | `bAllowGenAIInShipping = false`; `vg.GenAI.Enabled` desligada; sem segredos em `Config/` | `release.py` |
| 9 | Licenças | `THIRD_PARTY.md` sem célula vazia (84.4) | `release.py` |
| 10 | Créditos | A tela confere com o `THIRD_PARTY.md` e com as permissões | Você |
| 11 | Save | `docs/qa/save-matriz.md` (Cap. 79); um save do último *playtest* carrega ou é recusado com mensagem | Você |
| 12 | Máquina limpa, setor 1 | Os oito itens do Capítulo 62 | Você |
| 13 | Máquina limpa, jogo | Do menu aos créditos, nos **dois** finais (o segundo pelo "Continuar" no `CP_Final`) | Você |
| 14 | Preservação | A sessão inteira com a rede **desligada** e a lista da seção 84.5 | Você |

O item 3 julga o build Test porque a rota do portão é conduzida pelo cheat `VGPerfGate` (`UVGPerfGateSubsystem`), e o Shipping não tem cheats nem console; pelo mesmo motivo, o item 13 se joga como a jogadora jogaria. O que é mecânico (itens 1, 2, 3, 5, 7, 8 e 9) vai para *scripts*: esquecê-lo é questão de cansaço.

---

## 84.4 Licenças e créditos

Cada *asset* de terceiros chegou com uma licença, um contrato com condições: dar crédito, não redistribuir, não usar comercialmente, não modificar. O Capítulo 78 já avisou: registre a licença **na importação**. O registro é o `THIRD_PARTY.md`, na raiz do projeto:

| O quê | Onde | Origem | Licença | Crédito exigido | Cópia da licença |
|---|---|---|---|---|---|
| Unreal Engine | — | Epic Games | EULA (versão aceita em AAAA-MM-DD) | Conforme a EULA | `docs/licencas/` |
| Kit de painéis e tubulações | `/Game/Vigilia/Art/Props/Usina` | Fab | A licença do Fab para o item | Conforme a licença | `docs/licencas/` |
| Voz de Sônia | `/Game/Vigilia/Audio/Voice/Sonia` | Gravação com [pessoa] | Autorização por escrito | Sim | `docs/licencas/` |

Os itens são um **modelo** [HIPOTÉTICO]; o que importa é a forma: seis células preenchidas por linha, e `—` quando não se aplica. O `release.py` recusa célula vazia ou `?`.

O que procurar no texto da licença, que é sempre o que vale:

- **Creative Commons**: a CC0 dispensa atribuição; a BY exige; a NC proíbe uso comercial; a ND proíbe obras derivadas.
- **Fontes**: nem todas as licenças permitem embutir a fonte num programa; a *SIL Open Font License* permite, com condições.
- **A EULA da engine** prevê *royalties* a partir de certo faturamento e regras para as marcas da Epic; guarde a versão que você aceitou.
- **Vozes** exigem autorização por escrito da pessoa.
- **Conteúdo feito com IA** nas ferramentas da Parte X tem a origem registrada desde o Capítulo 70; algumas lojas pedem que esse uso seja declarado.

Este livro não dá orientação jurídica; se o jogo vai ser vendido, peça a leitura do `THIRD_PARTY.md` a quem entende de licenças.

A tela de créditos (Cap. 79, `ST_Creditos`) é conferida contra o `THIRD_PARTY.md` (todo crédito exigido, com o texto da licença) e contra as pessoas citadas, **só** com o nome que cada uma autorizou.

---

## 84.5 A IA generativa fora e a preservação

O ADR-0010 tirou a IA generativa do release com duas travas (Parte X): na **compilação**, `VG_WITH_GENAI` vale `0` em Shipping, e só a constante `bAllowGenAIInShipping = false` do `Build.cs` muda isso; na **execução**, `vg.GenAI.Enabled` nasce `0` e nenhum `.ini` a liga. No release, o `release.py` **verifica** as duas. A prova mais forte vem de ferramentas que já existem:

- **O `check_layers.py`.** Ninguém depende de `GenAI` (Cap. 77): nenhum código fora da pasta pode chamá-la. Dentro dela, os subsistemas não são criados em Shipping, e o caminho de rede do `UVGLLMSubsystem` nem é compilado.
- **O próprio Shipping.** O `Build.cs` do Capítulo 77 só declara `HTTP` e `Json` com `bWithGenAI`. Se algum código de `GenAI/` que os usa estiver fora da guarda `#if VG_WITH_GENAI`, o Shipping **não linka**. ⚠️ Nesse caso, envolva o código na guarda.

A Parte X deixou aberta a pergunta livre ao rádio (Cap. 74). A decisão mais simples compatível com o ADR-0010: no 1.0.0, **ela não existe**. `IA_FalarRadio` sai dos contextos de input, e o `UVGRadioTalkSubsystem` não é criado sem `VG_WITH_GENAI` (⚠️ confira o `ShouldCreateSubsystem` dele). Um menu autorado seria funcionalidade nova, fora do congelamento.

O endereço do *gateway* local no `DefaultGame.ini` não é segredo. O `release.py` procura o que **seria**: chaves como `ApiKey`, `Secret`, `Token` ou `Password` (Cap. 73).

O desafio do Capítulo 75 pediu um checklist de **preservação**: o que precisa ser verdade para a Vigília funcionar daqui a dez anos, sem serviço externo. No release, ele vira critério:

1. **Sem rede** e **sem conta**, do menu aos créditos; nenhuma chamada de rede compilada no Shipping.
2. **Nada depende de data**: nenhum conteúdo por calendário, nenhum build que expira.
3. **Saves locais e versionados**, com migração e recusa limpa (Cap. 56).
4. **Pré-requisitos no pacote** (`-prereqs`, Cap. 62).
5. **Reconstruível**: a *tag*, o `ENGINE.txt`, os símbolos e o `DEVLOG.md` arquivados.
6. **Acessibilidade sem console**: *flicker*, câmera e legendas no menu (Cap. 62).

Se a loja impuser um mecanismo próprio, ele é da loja: o build arquivado roda sem ele.

---

## 84.6 Distribuição

Os caminhos comuns são o arquivo direto, as páginas de jogos independentes e as lojas de PC. Diferem no administrativo (conta, taxas, revisão, página, classificação etária, SDKs), que muda e cada loja documenta; o livro não lista números nem processos. O que é seu:

- **O build é o mesmo**; um destino que exija outro gera outro **candidato**.
- **Nenhum SDK de loja no 1.0.0**: conquistas e nuvem seriam funcionalidade nova, contra a preservação.
- **Aviso de fotossensibilidade** na página e na primeira tela, com o *flicker* desligável (Cap. 11).
- **Cada versão publicada tem o seu arquivo**, e os seus símbolos nunca são apagados.

---

## 84.7 Um mundo para dois: o ramo `exp/coop-s1`

A spec (3.24) pede uma **versão multiplayer experimental de uma pequena parte** do jogo, para entender como a arquitetura muda quando o mundo é compartilhado. O ramo nasce da *tag*:

```text
git switch -c exp/coop-s1 v1.0.0
```

Três regras o acompanham: ele **nunca volta para `main` por *merge*** (o que for útil entra como mudança própria, com ADR); o **single-player continua funcionando** dentro dele; e ele **tem prazo**, duas semanas (14 a 20 horas), e o que não couber vira linha do relatório (Cap. 76).

O escopo é o do Interlúdio III: **só o setor 1**, **dois jogadores**, *listen server*, por convite ou IP direto. O segundo jogador é um segundo técnico do turno; o rádio segue a **opção A** (Sônia fala com "o turno"). Ficam de fora: entrar no meio, salvar, servidor dedicado, mais de dois jogadores, o prólogo, os setores 2 e 3 e o final.

### Três verbos

No single-player, cada sistema decide, guarda e mostra o próprio estado. Num mundo compartilhado, cada pedaço de estado ganha três papéis:

- **Dono:** o único lugar onde o estado muda (o servidor).
- **Espelho:** como as outras máquinas o veem (uma propriedade replicada).
- **Pedido:** como as outras máquinas pedem uma mudança (uma RPC `Server` validada).

A **apresentação local** (luz, legenda, som) deriva do espelho em cada máquina. O diagrama da spec, refeito para a Vigília:

```text
Single-player (1.0.0)            Cooperativo (exp/coop-s1, listen server)

Helena                           Anfitrião (servidor + jogador A)          Convidado (cliente B)
  │                                DONOS: fatos, diálogo, Presença,           │
  ▼                                Diretor, quests, portas, lanterna          │
sistemas ─► fatos ─► luzes,          ├── espelho (AVGCoopGameState) ─────────►│ fatos, rádio
                     falas,          ├── componentes replicados ─────────────►│ lanterna, portas
                     diário          │◄──────────── pedidos (RPC Server) ─────┤ lanterna, escolha,
                                                                                interação, leitura
```

O Interlúdio III previu que quase toda mudança seria **de dono**, e não de algoritmo; o inventário de quebras é o teste.

### O subsistema que existe duas vezes

O `UVGNarrativeSubsystem` é um `UGameInstanceSubsystem`: **um por processo**. No cooperativo há dois, e só o do servidor pode ser dono. Subsistemas não replicam, e por isso o espelho mora num ator que existe em todas as máquinas e pertence ao servidor: o **GameState**.

No cliente, o subsistema continua respondendo `HasFact` e `GetFacts` às luzes, às falas e ao diário, e continua anunciando `OnFactChanged`. Muda a **origem**: os fatos chegam pelo espelho, e criar um fato localmente é recusado, com a guarda no **dono do estado**, e não em cada chamador (Cap. 64). É o **modo réplica**.

---

## Estudos de caso

### GTA San Andreas — o cooperativo em marcadores

**[FATO PÚBLICO, observável jogando]** Na versão de PS2 de GTA San Andreas (Rockstar, 2004), um segundo jogador podia entrar em pontos marcados no mapa, para atividades fora das missões. Os dois dividiam a mesma tela, e a câmera se afastava para enquadrar os dois, o que obrigava a dupla a andar junta.

**[INFERÊNCIA]** Isolar o modo das missões poupou os sistemas de missão, de cena e de save de saber que existia um segundo jogador, e a câmera única transformou uma restrição técnica numa regra de jogo.

**Lição para a Vigília:** é a estratégia do `exp/coop-s1` (só o setor 1, sem save, prólogo nem final). E a câmera de San Andreas é o rádio da Vigília: um sistema que o single-player tinha como **único**, cuja versão compartilhada é decisão de design antes de ser técnica.

### Outlast e The Outlast Trials — o terror a dois é outro jogo

**[FATO PÚBLICO]** A Red Barrels lançou dois jogos de terror single-player, Outlast (2013) e Outlast 2 (2017). O jogo seguinte do estúdio, The Outlast Trials, lançado em acesso antecipado em 2023, é cooperativo, para até quatro pessoas.

**[INFERÊNCIA]** O estúdio não acrescentou um modo cooperativo a uma história escrita para uma pessoa: fez um jogo desenhado para grupo. O terror de Outlast depende de estar sozinho.

**Lição para a Vigília:** com a opção A, Sônia fala com "o turno", e a intimidade com Helena se perde. A Vigília cooperativa seria outro jogo; o ramo é para aprender arquitetura (ADR-0012).

---

## Comparação com o desenvolvimento tradicional

| Conceito | O que você conhece | Onde a analogia cai |
|---|---|---|
| Candidato promovido | *Release candidate* | Não há *rollback* seu |
| `THIRD_PARTY.md` | Inventário de dependências (SBOM) | As dependências são arte, som, fonte e voz; uma voz exige autorização de uma pessoa |
| Espelho de fatos e modo réplica | Réplica de leitura | É a mesma classe que, no single-player, é a dona, e a diferença aplicada dispara as reações locais de sempre |
| Pedido validado | Validação de entrada numa API | Erro de forma desconecta; erro de regra recusa em silêncio |

---

## Unreal Engine: o que existe e o que falta

**Para o release:** `BuildCookRun` (Cap. 62), `ProjectVersion`, os `.pdb` e um cliente de relatório de *crash*, que precisa de um destino que a Vigília 1.0.0 não tem (preservação); os símbolos leem os *dumps* que uma jogadora lhe mandar (⚠️ a pasta deles depende da versão).

**Para o ramo**, o que a Parte IX usou: `AGameStateBase` (em todas as máquinas, com `GetServerWorldTimeSeconds()`), `ReplicatedUsing`/`DOREPLIFETIME`, RPCs `Server` com `WithValidation` em atores e componentes possuídos pelo cliente, `ForceNetUpdate` e a emulação de rede do PIE.

**O que falta:** checklist de release, registro de licenças, histórico de builds, preservação. E **subsistemas não replicam**: `UGameInstanceSubsystem` e `UWorldSubsystem` não têm propriedades replicadas nem RPCs. O espelho precisa de um ator.

---

## Abordagens: como o cliente fica sabendo dos fatos

| Critério | **A. Conjunto replicado no GameState** | B. RPC *multicast* por mudança | C. `FFastArraySerializer` |
|---|---|---|---|
| Complexidade | Baixa: um campo, um `OnRep` | Baixa | Média: item, marcação de sujo, *callbacks* |
| Rede | Reenvia o contêiner a cada mudança (dezenas de tags: irrelevante) | Mínima | Mínima: só a diferença |
| Perda e entrada tardia | Corretas por construção: é estado | Frágeis: quem chega depois não recebe a história | Corretas |
| Extensibilidade | Contadores pedem outro campo | Idem | Idem |
| Manutenção | Uma cópia do dono | Um evento por operação | Código de rede próprio |
| Prototipação | Imediata | Imediata | Lenta |
| Adequação à Vigília | **Alta** | Baixa | Sobra para dezenas de fatos |

**Decisão: A**, como o Interlúdio III previu: a lição do Capítulo 65 aplicada à narrativa, replicar **estado** e não eventos. A B quebra no primeiro pacote perdido. A C só se o conjunto chegar a milhares de itens.

---

## Implementação

### 1. As verificações de release

Um irmão do `check_layers.py`: ferramenta de projeto, fora do jogo, que sai com código 1 quando algo está errado.

```python
#!/usr/bin/env python3
"""Verificações de release da Vigília (Cap. 84). Código de saída 1 se alguma falhar.
Uso: python Tools/release.py check 1.0.0
     python Tools/release.py record 1.0.0 Shipping <pasta do build>"""
import csv, datetime, re, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HISTORY = "docs/release/builds.csv"
GENAI_ON = re.compile(r"^\s*vg\.GenAI\.Enabled\s*=\s*(1|true)\b", re.I | re.M)
SECRET = re.compile(r"^[^;\n]*(api_?key|secret|token|password|bearer)\w*\s*=", re.I | re.M)
ALLOW_FLAG = re.compile(r"const\s+bool\s+bAllowGenAIInShipping\s*=\s*false\s*;")


def git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True, check=True).stdout.strip()


def check(version):
    errors = []
    game_ini = (ROOT / "Config/DefaultGame.ini").read_text(encoding="utf-8")
    if not re.search(rf"^ProjectVersion={re.escape(version)}\s*$", game_ini, re.M):
        errors.append(f"DefaultGame.ini: ProjectVersion não é {version}")
    for ini in sorted((ROOT / "Config").rglob("*.ini")):
        text = ini.read_text(encoding="utf-8", errors="replace")
        if GENAI_ON.search(text):
            errors.append(f"{ini.name}: liga vg.GenAI.Enabled (ADR-0010)")
        errors += [f"{ini.name}: parece segredo: {m.group(0).strip()}" for m in SECRET.finditer(text)]
    if not ALLOW_FLAG.search((ROOT / "Source/Vigilia/Vigilia.Build.cs").read_text(encoding="utf-8")):
        errors.append("Vigilia.Build.cs: bAllowGenAIInShipping precisa ser false (ADR-0010)")
    third = ROOT / "THIRD_PARTY.md"
    rows = [l for l in third.read_text(encoding="utf-8").splitlines()
            if l.startswith("|") and set(l) - set("|-: ")] if third.exists() else []
    if not rows:
        errors.append("THIRD_PARTY.md ausente ou vazio")
    errors += [f"THIRD_PARTY.md incompleto: {r}" for r in rows
               if {"", "?"} & {c.strip() for c in r.strip().strip("|").split("|")}]
    # O histórico é o único arquivo que um build pode sujar.
    if git("status", "--porcelain", "--", ".", f":(exclude){HISTORY}"):
        errors.append("árvore suja: o commit não descreveria o build")
    for error in errors:
        print("RELEASE:", error)
    return 1 if errors else 0


def record(version, config, folder):
    path = ROOT / HISTORY
    size_mb = sum(f.stat().st_size for f in Path(folder).rglob("*") if f.is_file()) / 2**20
    is_new = not path.exists()
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        if is_new:
            writer.writerow(["data", "versao", "config", "commit", "tamanho_mb", "resultado", "notas"])
        writer.writerow([datetime.date.today().isoformat(), version, config,
                         git("rev-parse", "--short", "HEAD"), round(size_mb), "gerado", ""])
    return 0


if __name__ == "__main__":
    command, *args = sys.argv[1:] or [""]
    if command == "check" and len(args) == 1:
        sys.exit(check(*args))
    if command == "record" and len(args) == 3:
        sys.exit(record(*args))
    sys.exit(__doc__)
```

### 2. 🔁 O *script* de build em modo candidato

**O que havia** (Caps. 62 e 77): nada ligava um build ao seu *commit*, e os símbolos de um build eram sobrescritos pelos do seguinte. **A solução**: um segundo argumento opcional, a versão. Sem ele, nada muda.

```bat
rem Tools/BuildVigilia.bat  —  uso: BuildVigilia.bat [Shipping|Test|Development] [versao]
rem (Cap. 84) Com a versao, o build e um CANDIDATO a release.
set VER=%2

rem 0. Candidato: versao, arvore limpa, IA generativa fora, segredos, licencas.
if not "%VER%"=="" (
    python "%ROOT%\Tools\release.py" check %VER% || exit /b 1
)

rem 1-2. Camadas, testes e BuildCookRun: como nos Caps. 62 e 77.

rem 3. Sem versao: simbolos ao lado, como no Cap. 62.
if "%VER%"=="" (
    xcopy "%ROOT%\Binaries\Win64\*.pdb" "%ROOT%\Builds\%CFG%-Symbols\" /Y /I >nul
    exit /b 0
)
rem    Candidato: build, simbolos e relatorio numa pasta com o commit no nome; uma linha no historico.
for /f %%c in ('git -C "%ROOT%" rev-parse --short HEAD') do set COMMIT=%%c
set OUT=%ROOT%\Builds\Release\%VER%-%COMMIT%-%CFG%
xcopy "%ROOT%\Builds\%CFG%" "%OUT%\Game\" /E /I /Y >nul
xcopy "%ROOT%\Binaries\Win64\*.pdb" "%OUT%\Symbols\" /Y /I >nul
xcopy "%ROOT%\Builds\TestReport" "%OUT%\TestReport\" /E /I /Y >nul
python "%ROOT%\Tools\release.py" record %VER% %CFG% "%OUT%\Game" || exit /b 1
echo Candidato %VER% (%COMMIT%, %CFG%) em %OUT%.
```

O portão de performance tem *script* próprio, `Tools\PerfGate.bat` (Cap. 83), rodado depois de `Tools\BuildVigilia.bat Test`: ele abre o build Test, percorre a rota com o cheat `VGPerfGate`, grava `Saved/Profiling/VGPerf.log` e o entrega ao `Tools/perf_gate.py`, que o julga contra o `Tools/perf_budget.json`. Saída diferente de zero bloqueia o release. Ele fica fora do `BuildVigilia.bat` de propósito: o build pode ser gerado em qualquer máquina, mas o portão só vale na máquina-alvo, com o resto fechado. O `VGPerf.log` e a saída do portão vão para a pasta `perf/` do candidato.

### 3. A versão, os mapas e a trava

```ini
; Config/DefaultGame.ini (🔁 Cap. 84 — o que muda em relação ao Cap. 62)
[/Script/EngineSettings.GeneralProjectSettings]
ProjectVersion=1.0.0

[/Script/UnrealEd.ProjectPackagingSettings]
+MapsToCook=(FilePath="/Game/Vigilia/Maps/L_Subestacao")
+MapsToCook=(FilePath="/Game/Vigilia/Maps/L_Turbinas")
+MapsToCook=(FilePath="/Game/Vigilia/Maps/L_Turbinas_Poco")
+MapsToCook=(FilePath="/Game/Vigilia/Maps/L_Final")
```

O subnível do poço entra explicitamente: se ele for carregado por código (ADR-0011), nenhum nível o referencia, e o *cook* não o vê (⚠️ se estiver na lista de *streaming* do `L_Turbinas`, a referência basta; listar não custa nada). A linha que o `release.py` procura no `Build.cs` é a do Capítulo 75, `const bool bAllowGenAIInShipping = false;`, com o comentário que manda revisar o ADR-0010 e este checklist. O `Build.cs` final do Capítulo 77 escreve a expressão sem a constante; mantenha a forma do 75, que diz a quem procurar que aquilo é uma decisão de produto.

### 4. 🔁 A narrativa em modo réplica

**O que havia** (Cap. 46): o dono dos fatos aceitava `AddFact` de qualquer chamador. **O problema**: o subsistema do cliente criaria fatos que o servidor nunca vê (o cisma do Cap. 64). **A solução**: um modo em que ele recusa criar fatos e recebe o conjunto do servidor, anunciando a diferença.

```cpp
// Source/Vigilia/Narrative/VGNarrativeSubsystem.h (🔁 Cap. 84 — adições)
public:
    /** Cliente cooperativo: os fatos chegam pelo espelho; criar fato aqui é recusado. */
    void SetReplicaMode(bool bEnable);
    /** Só em modo réplica: aplica o conjunto do servidor e anuncia a DIFERENÇA. */
    void ApplyReplicatedFacts(const FGameplayTagContainer& Mirror);
private:
    bool RefuseIfReplica(const TCHAR* Operation, FGameplayTag Tag) const;
    bool bReplicaMode = false;
    bool bHasMirror = false; // o primeiro espelho é um estado inteiro, não uma diferença
```

```cpp
// Source/Vigilia/Narrative/VGNarrativeSubsystem.cpp (🔁 Cap. 84 — essencial)
#include "World/Coop/VGCoopRules.h"

void UVGNarrativeSubsystem::SetReplicaMode(bool bEnable)
{
    if (bReplicaMode != bEnable)
    {
        bReplicaMode = bEnable;
        bHasMirror = false;
    }
}

bool UVGNarrativeSubsystem::RefuseIfReplica(const TCHAR* Operation, FGameplayTag Tag) const
{
    // Barulhento de propósito: cada aviso destes é uma linha do inventário de quebras.
    UE_CLOG(bReplicaMode, LogVigilia, Warning, TEXT("Narrativa (réplica): %s(%s) recusado."), Operation, *Tag.ToString());
    return bReplicaMode;
}

void UVGNarrativeSubsystem::AddFact(FGameplayTag Fact)
{
    if (!RefuseIfReplica(TEXT("AddFact"), Fact) && State.AddFact(Fact))
    {
        Announce(Fact, true);
    }
}
// A mesma guarda abre SetExclusiveFact, RemoveFact e AddToCounter (que devolve 0).

void UVGNarrativeSubsystem::ApplyReplicatedFacts(const FGameplayTagContainer& Mirror)
{
    if (!ensure(bReplicaMode))
    {
        return;
    }
    if (!bHasMirror) // primeiro espelho: o estado inteiro foi trocado, como num load (Cap. 46)
    {
        bHasMirror = true;
        State.Facts = Mirror;
        OnRestored.Broadcast();
        return;
    }
    FGameplayTagContainer Added, Removed;
    VGCoopRules::DiffFacts(State.Facts, Mirror, Added, Removed);
    State.Facts = Mirror;                                       // estado primeiro...
    for (const FGameplayTag& Fact : Removed) { Announce(Fact, false); } // ...remoções antes,
    for (const FGameplayTag& Fact : Added)   { Announce(Fact, true); }  // como no SetExclusiveFact
}
```

```cpp
// Source/Vigilia/World/Coop/VGCoopRules.h
#pragma once
#include "CoreMinimal.h"
#include "GameplayTagContainer.h"
#include "Player/VGFlashlightRules.h"

/** Regras puras do ramo cooperativo (Cap. 84). */
namespace VGCoopRules
{
    /** Folga de forma para o índice de escolha vindo de um cliente. */
    constexpr int32 MaxDialogueChoices = 8;

    /** Em New e não em Old (Added), e o contrário (Removed). Comparação EXATA. */
    inline void DiffFacts(const FGameplayTagContainer& Old, const FGameplayTagContainer& New,
                          FGameplayTagContainer& OutAdded, FGameplayTagContainer& OutRemoved)
    {
        OutAdded.Reset();
        OutRemoved.Reset();
        for (const FGameplayTag& Tag : New) { if (!Old.HasTagExact(Tag)) { OutAdded.AddTag(Tag); } }
        for (const FGameplayTag& Tag : Old) { if (!New.HasTagExact(Tag)) { OutRemoved.AddTag(Tag); } }
    }

    /** Só a jogadora aperta botões; bateria e fim de pulso são do servidor. */
    inline bool IsPlayerFlashlightInput(EVGFlashlightInput Input)
    {
        return Input == EVGFlashlightInput::TogglePressed || Input == EVGFlashlightInput::OverchargeRequested;
    }
}
```

### 5. 🔁 O rádio no servidor

**O que havia** (Cap. 44): um subsistema de mundo por máquina, decidindo a fila e tocando a voz na mesma função (`StartLine`). **A solução**: só o do servidor decide e publica **o que está na tela**; o do cliente, em modo réplica, toca isso de onde o servidor já está.

```cpp
// Source/Vigilia/Narrative/VGDialogueSubsystem.h (🔁 Cap. 84 — adições)
/** O que qualquer máquina precisa para mostrar o rádio. Conversation nula = nada na tela. */
USTRUCT()
struct FVGDialoguePresentation
{
    GENERATED_BODY()
    UPROPERTY() TObjectPtr<const UVGDialogueData> Conversation;
    UPROPERTY() int32 NodeIndex = INDEX_NONE;
    UPROPERTY() bool bChoosing = false;
    UPROPERTY() TArray<int32> VisibleChoices; // decididas no servidor
    UPROPERTY() double StartServerTime = 0.0; // preenchido por quem publica
    UPROPERTY() int32 Serial = 0;             // a mesma fala retomada é outra apresentação
};
DECLARE_MULTICAST_DELEGATE(FVGDialoguePresentationNative);

// Na classe:
public:
    void SetReplicaMode(bool bEnable) { bReplicaMode = bEnable; }
    const FVGDialoguePresentation& GetPresentation() const { return Presentation; }
    void ApplyRemotePresentation(const FVGDialoguePresentation& Remote, double ElapsedSeconds);
    FVGDialoguePresentationNative OnPresentationChangedNative;
private:
    void Present(int32 Node, bool bChoosing);
    FVGDialogueLineView MakeLineView(const FVGDialogueNode& Node) const; // 🔁 extraído de StartLine
    bool bReplicaMode = false;
    FVGDialoguePresentation Presentation; // servidor: a tela agora
    FVGDialoguePresentation Shown;        // cliente: o último aplicado
```

```cpp
// Source/Vigilia/Narrative/VGDialogueSubsystem.cpp (🔁 Cap. 84 — essencial)
// Em modo réplica: RequestConversation devolve false; Tick retorna logo; ChooseOption vira pedido
// ao AVGPlayerController local (ServerChooseDialogueOption) — caminho que só existe no cliente.
// No servidor, Present é chamado onde a tela muda: StartLine, FinishLine, TakeBranch, Interrupt.

void UVGDialogueSubsystem::Present(int32 Node, bool bChoosing)
{
    Presentation.Conversation = Node == INDEX_NONE ? nullptr : Current.Conversation.Get();
    Presentation.NodeIndex = Node;
    Presentation.bChoosing = bChoosing;
    Presentation.VisibleChoices = bChoosing ? VisibleChoices : TArray<int32>();
    ++Presentation.Serial;
    OnPresentationChangedNative.Broadcast(); // no single-player, ninguém escuta
}

void UVGDialogueSubsystem::ApplyRemotePresentation(const FVGDialoguePresentation& Remote, double ElapsedSeconds)
{
    if (!bReplicaMode || Remote.Serial == Shown.Serial)
    {
        return;
    }
    if (Voice.IsValid()) { Voice->Stop(); } // 1. fecha o que estava na tela, como o servidor fechou
    if (Shown.Conversation)
    {
        if (Shown.bChoosing) { OnChoicesClosed.Broadcast(); } else { OnLineEnded.Broadcast(); }
    }
    Shown = Remote;
    const FVGDialogueNode* Node = Remote.Conversation && Remote.Conversation->Nodes.IsValidIndex(Remote.NodeIndex)
        ? &Remote.Conversation->Nodes[Remote.NodeIndex] : nullptr;
    if (!Node)
    {
        return; // silêncio
    }
    if (Remote.bChoosing) // 2. escolhas: os índices vieram do servidor
    {
        TArray<FText> Texts;
        for (const int32 Index : Remote.VisibleChoices)
        {
            if (Node->Choices.IsValidIndex(Index)) { Texts.Add(Node->Choices[Index].Text); }
        }
        OnChoicesPresented.Broadcast(Texts);
        return;
    }
    FVGDialogueLineView View = MakeLineView(*Node); // 3. fala: começa de onde o servidor está
    View.Duration -= static_cast<float>(ElapsedSeconds);
    if (View.Duration <= 0.0f)
    {
        Shown.Conversation = nullptr; // chegou depois do fim: fala atrasada é pior que nenhuma (Cap. 44)
        return;
    }
    if (Node->Voice)
    {
        Voice = UGameplayStatics::SpawnSound2D(this, Node->Voice, 1.0f, 1.0f, static_cast<float>(ElapsedSeconds));
    }
    OnLineStarted.Broadcast(View);
}
```

A resposta do convidado é um pedido no `AVGPlayerController`, o ator que a conexão dele possui:

```cpp
// Source/Vigilia/Player/VGPlayerController (🔁 Cap. 84 — adição)
UFUNCTION(Server, Reliable, WithValidation)
void ServerChooseDialogueOption(int32 VisibleIndex);

bool AVGPlayerController::ServerChooseDialogueOption_Validate(int32 VisibleIndex)
{
    // Forma: índice impossível só vem de cliente adulterado. Falhar desconecta (Cap. 66).
    return VisibleIndex >= 0 && VisibleIndex < VGCoopRules::MaxDialogueChoices;
}

void AVGPlayerController::ServerChooseDialogueOption_Implementation(int32 VisibleIndex)
{
    // Regra: fora de Choosing, ChooseOption recusa em silêncio. É o destino de quem responde em segundo.
    if (UVGDialogueSubsystem* Dialogue = GetWorld()->GetSubsystem<UVGDialogueSubsystem>())
    {
        Dialogue->ChooseOption(VisibleIndex);
    }
}
```

### 6. O espelho: `AVGCoopGameState`

```cpp
// Source/Vigilia/World/Coop/VGCoopGameState.h
#pragma once
#include "CoreMinimal.h"
#include "GameFramework/GameStateBase.h"
#include "GameplayTagContainer.h"
#include "Narrative/VGDialogueSubsystem.h"
#include "VGCoopGameState.generated.h"

/** Ramo exp/coop-s1 (ADR-0012). Publica o que só o servidor decide. Não decide nada: copia do dono. */
UCLASS()
class VIGILIA_API AVGCoopGameState : public AGameStateBase
{
    GENERATED_BODY()
public:
    virtual void GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const override;
protected:
    virtual void BeginPlay() override;
    virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;
private:
    void PublishFacts();                                         // servidor
    void HandleFactChanged(FGameplayTag, bool) { PublishFacts(); }
    void HandlePresentationChanged();
    void EnterReplicaMode();                                     // cliente

    UFUNCTION() void OnRep_Facts();
    UFUNCTION() void OnRep_RadioLine();

    /** Cópia dos fatos do UVGNarrativeSubsystem do SERVIDOR. Estado, não evento. */
    UPROPERTY(ReplicatedUsing = OnRep_Facts)
    FGameplayTagContainer Facts;

    /** A fala de rádio em curso, com o início no relógio do servidor. */
    UPROPERTY(ReplicatedUsing = OnRep_RadioLine)
    FVGDialoguePresentation RadioLine;
};
```

```cpp
// Source/Vigilia/World/Coop/VGCoopGameState.cpp
#include "World/Coop/VGCoopGameState.h"
#include "Engine/World.h"
#include "Narrative/VGNarrativeSubsystem.h"
#include "Net/UnrealNetwork.h"

void AVGCoopGameState::GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const
{
    Super::GetLifetimeReplicatedProps(OutLifetimeProps);
    DOREPLIFETIME(AVGCoopGameState, Facts);
    DOREPLIFETIME(AVGCoopGameState, RadioLine);
}

void AVGCoopGameState::BeginPlay()
{
    Super::BeginPlay();
    if (!HasAuthority())
    {
        EnterReplicaMode();
        return;
    }
    if (UVGNarrativeSubsystem* Narrative = UVGNarrativeSubsystem::Get(this)) // servidor: escuta os donos
    {
        Narrative->OnFactChangedNative.AddUObject(this, &AVGCoopGameState::HandleFactChanged);
        Narrative->OnRestored.AddUObject(this, &AVGCoopGameState::PublishFacts);
        PublishFacts();
    }
    if (UVGDialogueSubsystem* Dialogue = GetWorld()->GetSubsystem<UVGDialogueSubsystem>())
    {
        Dialogue->OnPresentationChangedNative.AddUObject(this, &AVGCoopGameState::HandlePresentationChanged);
    }
}

void AVGCoopGameState::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
    if (UVGNarrativeSubsystem* Narrative = UVGNarrativeSubsystem::Get(this))
    {
        Narrative->OnFactChangedNative.RemoveAll(this);
        Narrative->OnRestored.RemoveAll(this);
        if (!HasAuthority()) // a GameInstance sobrevive à sessão; o espelho não é progresso do convidado
        {
            Narrative->SetReplicaMode(false);
            Narrative->ResetForNewGame();
        }
    }
    Super::EndPlay(EndPlayReason);
}

void AVGCoopGameState::PublishFacts()
{
    if (const UVGNarrativeSubsystem* Narrative = UVGNarrativeSubsystem::Get(this))
    {
        Facts = Narrative->GetFacts(); // o conjunto: uma cascata de fatos vira um envio só
        ForceNetUpdate();              // fato é raro e importante: não espere a próxima janela
    }
}

void AVGCoopGameState::HandlePresentationChanged()
{
    RadioLine = GetWorld()->GetSubsystem<UVGDialogueSubsystem>()->GetPresentation();
    RadioLine.StartServerTime = GetServerWorldTimeSeconds();
    ForceNetUpdate();
}

void AVGCoopGameState::EnterReplicaMode()
{
    // Idempotente: o primeiro OnRep pode chegar antes do BeginPlay (⚠️ não conte com a ordem).
    if (UVGNarrativeSubsystem* Narrative = UVGNarrativeSubsystem::Get(this)) { Narrative->SetReplicaMode(true); }
    if (UVGDialogueSubsystem* Dialogue = GetWorld()->GetSubsystem<UVGDialogueSubsystem>()) { Dialogue->SetReplicaMode(true); }
}

void AVGCoopGameState::OnRep_Facts()
{
    EnterReplicaMode();
    if (UVGNarrativeSubsystem* Narrative = UVGNarrativeSubsystem::Get(this)) { Narrative->ApplyReplicatedFacts(Facts); }
}

void AVGCoopGameState::OnRep_RadioLine()
{
    EnterReplicaMode();
    const double Elapsed = FMath::Max(0.0, GetServerWorldTimeSeconds() - RadioLine.StartServerTime);
    if (UVGDialogueSubsystem* Dialogue = GetWorld()->GetSubsystem<UVGDialogueSubsystem>())
    {
        Dialogue->ApplyRemotePresentation(RadioLine, Elapsed);
    }
}
```

O GameState mora em `World/Coop/`: `World` é gameplay, pode incluir `Narrative` e `Player`, e o `check_layers.py` não muda.

### 7. 🔁 A lanterna como pedido

**O que havia** (Cap. 51): `Toggle()` aplicava localmente, e `EnterState` concedia as tags **e** acendia o feixe; no convidado, a tag ia para a cópia local, que a Presença (só no servidor) nunca via. **A solução**: com autoridade, aplica; sem, pede. O estado replica, e cada máquina deriva dele o feixe. `EVGFlashlightInput` ganha `UENUM()`, porque vira parâmetro de RPC.

```cpp
// Source/Vigilia/Player/VGFlashlightComponent.h (🔁 Cap. 84 — adições e mudanças)
public:
    virtual void GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const override;
private:
    void RequestInput(EVGFlashlightInput Input); // Toggle e RequestOvercharge passam por aqui

    UFUNCTION(Server, Reliable, WithValidation)
    void ServerFlashlightInput(EVGFlashlightInput Input);

    UFUNCTION()
    void OnRep_State(EVGFlashlightState OldState);

    void ApplyPresentation(EVGFlashlightState OldState, EVGFlashlightState NewState);

    UPROPERTY(ReplicatedUsing = OnRep_State)
    EVGFlashlightState State = EVGFlashlightState::Off; // 🔁 era um campo comum
```

```cpp
// Source/Vigilia/Player/VGFlashlightComponent.cpp (🔁 Cap. 84 — essencial)
// Construtor: + SetIsReplicatedByDefault(true). GetLifetimeReplicatedProps: DOREPLIFETIME(UVGFlashlightComponent, State).

void UVGFlashlightComponent::Toggle()            { RequestInput(EVGFlashlightInput::TogglePressed); }
void UVGFlashlightComponent::RequestOvercharge() { RequestInput(EVGFlashlightInput::OverchargeRequested); }

void UVGFlashlightComponent::RequestInput(EVGFlashlightInput Input)
{
    if (GetOwner()->HasAuthority()) { Apply(Input); }   // single-player e anfitrião: como antes
    else                            { ServerFlashlightInput(Input); } // convidado: um pedido
}

bool UVGFlashlightComponent::ServerFlashlightInput_Validate(EVGFlashlightInput Input)
{
    return VGCoopRules::IsPlayerFlashlightInput(Input); // forma: bateria e fim de pulso não vêm do cliente
}

void UVGFlashlightComponent::ServerFlashlightInput_Implementation(EVGFlashlightInput Input)
{
    Apply(Input); // regra: VGFlashlightRules::Next recusa em silêncio (sem carga, pulso em recarga)
}

// Apply ganha na primeira linha: if (!GetOwner()->HasAuthority()) { return; }
// A bateria replicada não decide nada no cliente.

void UVGFlashlightComponent::EnterState(EVGFlashlightState NewState) // só com autoridade
{
    const EVGFlashlightState OldState = State;
    State = NewState;
    StateEnteredAt = Now();
    // ... as tags de status, como no Cap. 51: são DECISÃO, e a Presença as lê no servidor.
    ApplyPresentation(OldState, NewState); // o servidor faz à mão o que o OnRep faz nos clientes
    if (NewState == EVGFlashlightState::Overcharge)
    {
        FireOverchargePulse(); // por último, como no Cap. 51
    }
}

void UVGFlashlightComponent::OnRep_State(EVGFlashlightState OldState)
{
    StateEnteredAt = Now(); // aproximado: no cliente, só a apresentação usa
    ApplyPresentation(OldState, State);
}

void UVGFlashlightComponent::ApplyPresentation(EVGFlashlightState OldState, EVGFlashlightState NewState)
{
    SetVisibility(VGFlashlightRules::IsBeamVisible(NewState));
    SetComponentTickEnabled(VGFlashlightRules::IsBeamVisible(NewState));
    UpdateIntensity();
    OnStateChanged.Broadcast(OldState, NewState);
}
```

No `TickComponent`, o fim do pulso e a drenagem ficam dentro de `if (GetOwner()->HasAuthority())`; cintilação e recuperação do feixe são apresentação. A `UVGBatteryComponent` segue o padrão, com a carga só para o dono (`COND_OwnerOnly`). ⚠️ Um componente de cena replicado também replica visibilidade e transformação relativa; aqui ambas derivam do estado ou são constantes, mas confira o Blueprint da lanterna.

### 8. O GameMode cooperativo

```cpp
// Source/Vigilia/World/Coop/VGCoopGameMode (essencial)
UCLASS()
class VIGILIA_API AVGCoopGameMode : public AVGGameMode
{
    GENERATED_BODY()
public:
    AVGCoopGameMode()
    {
        GameStateClass = AVGCoopGameState::StaticClass();
        bPauseable = false; // num mundo compartilhado, o menu não para o mundo
    }
    virtual void StartPlay() override; // ResetForNewGame + AddFact de cada StartFacts (no servidor)

    /** 🔁 nova no AVGGameMode: true = o checkpoint grava (single-player). Aqui, só guarda o nome. */
    virtual bool HandleCheckpointReached(FName CheckpointTag) override { LastCheckpoint = CheckpointTag; return false; }

    /** 🔁 virtual desde agora: RestartPlayerAtPlayerStart no APlayerStart cujo PlayerStartTag
        é LastCheckpoint (AVGCheckpoint é um APlayerStart); sem ele, RestartPlayer. Nada recarrega. */
    virtual void HandleRespawnRequest(AController* Controller) override;

protected:
    /** O ramo começa no setor 1, sem prólogo: os fatos que ele daria nascem aqui. */
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Coop")
    FGameplayTagContainer StartFacts;
private:
    FName LastCheckpoint;
};
```

O `AVGCheckpoint` (pasta `Save`, que pode incluir gameplay) muda uma linha: só pede o save se `HasAuthority() && GameMode->HandleCheckpointReached(PlayerStartTag)`. O `AVGGameMode` base devolve `true`, e o single-player grava como antes. Procurar por `APlayerStart`, a classe da engine, evita uma segunda dependência do GameMode em `Save`, além da exceção `("World", "Save")` declarada no Capítulo 77.

### 9. Teste

```cpp
// Source/Vigilia/Tests/VGCoopRulesTest.cpp
#include "Misc/AutomationTest.h"
#include "Core/VGGameplayTags.h"
#include "World/Coop/VGCoopRules.h"

#if WITH_DEV_AUTOMATION_TESTS

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FVGCoopRulesTest, "Vigilia.Net.Coop.Rules",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ProductFilter)

bool FVGCoopRulesTest::RunTest(const FString& Parameters)
{
    // Grupo exclusivo trocado no servidor e um fato que não mudou.
    FGameplayTagContainer Old, New, Added, Removed;
    Old.AddTag(TAG_Status_Movement_Sprinting);
    Old.AddTag(TAG_World_Sector_Powered);
    New.AddTag(TAG_Status_Movement_Crouched);
    New.AddTag(TAG_World_Sector_Powered);
    VGCoopRules::DiffFacts(Old, New, Added, Removed);
    TestTrue(TEXT("Só o valor novo"), Added.Num() == 1 && Added.HasTagExact(TAG_Status_Movement_Crouched));
    TestTrue(TEXT("Só a irmã"), Removed.Num() == 1 && Removed.HasTagExact(TAG_Status_Movement_Sprinting));

    // Comparação EXATA: o pai explícito é fato novo, mesmo com um filho dele em Old.
    New.AddTag(TAG_Status_Movement_Crouched.GetTag().RequestDirectParent());
    VGCoopRules::DiffFacts(Old, New, Added, Removed);
    TestEqual(TEXT("Pai explícito detectado"), Added.Num(), 2);

    VGCoopRules::DiffFacts(New, New, Added, Removed);
    TestTrue(TEXT("Espelho igual: nada a anunciar"), Added.IsEmpty() && Removed.IsEmpty());

    TestTrue(TEXT("Interruptor"), VGCoopRules::IsPlayerFlashlightInput(EVGFlashlightInput::TogglePressed));
    TestFalse(TEXT("Bateria é do servidor"), VGCoopRules::IsPlayerFlashlightInput(EVGFlashlightInput::BatteryReplaced));
    return true;
}

#endif
```

### Explicação das decisões

- **O `release.py` impede esquecimentos**, com expressões estritas: um falso positivo custa um minuto, e um segredo publicado não tem conserto. O histórico fica fora da verificação de árvore limpa, ou o build Test sujaria a árvore para o Shipping do mesmo *commit*.
- **Modo réplica explícito, e não deduzido do modo de rede**: o subsistema vive mais que qualquer mundo e não sabe o que é uma sessão; o GameState dela liga e desliga o modo.
- **O primeiro espelho é um *restore*; os seguintes, diferenças**, anunciadas pelos canais de sempre: luminárias, `UVGFactGateComponent`, falas e diário reagem no cliente sem mudar. A comparação é exata porque `HasTag` responde pela hierarquia.
- **Declaração de relógio.** O servidor carimba a fala no relógio de jogo (`GetServerWorldTimeSeconds`); o diálogo mede no de **áudio**. Coincidem sem pausa nem dilatação, e o cooperativo não pausa (⚠️ se o seu setor 1 dilatar o tempo, a fala desliza).
- **Uma RPC com a entrada, para a lanterna.** A validação de forma tem o que conferir (um cliente que manda `BatteryReplaced` está adulterado); a de regra é a própria `VGFlashlightRules::Next`, que recusa em silêncio (Parte IX).
- **No single-player, nada muda**: sem rede, todo ator tem autoridade, o modo réplica nunca liga e ninguém escuta `OnPresentationChangedNative`.

---

## Projeto Final — o release 1.0.0 e o turno de dois

### O release

```text
1. Congelar     ProjectVersion=1.0.0; THIRD_PARTY.md e ST_Creditos completos; árvore limpa
2. Test         Tools\BuildVigilia.bat Test 1.0.0
3. Performance  Tools\PerfGate.bat na máquina-alvo → saída 0; VGPerf.log para perf\
4. Shipping     Tools\BuildVigilia.bat Shipping 1.0.0   (o MESMO commit)
5. Verificar    itens 10 a 14 da seção 84.3; reprovado → bug A, novo commit, passo 2
6. Promover     tag v1.0.0; o candidato vira Release\1.0.0, com DEVLOG.md e o resto do arquivo
```

- [ ] `THIRD_PARTY.md` e `ST_Creditos` completos; os quatro mapas novos na lista de *cook*.
- [ ] `Release/1.0.0` completo, em dois lugares, com o candidato promovido sem recompilar.
- [ ] Milestone 10 (build) fechado: o Shipping roda numa máquina limpa, sem rede.

### O ramo

1. **Antes de mudar qualquer coisa**, jogue o setor 1 a dois (*listen server*, 100 ms, 2% de perda) e registre o que quebra, como a Arena fez com Q1–Q10. A tabela abaixo é o que se espera; o seu inventário é o que você encontrou.
2. Corrija por gravidade: primeiro o que perde dados (C1), depois o que gera cisma (C2–C6).
3. Valide com dois builds Development empacotados, em duas máquinas, ligados por `open <IP>`.

### O inventário de quebras

✅ resolvido pelo código deste capítulo; 🔧 pela receita da linha; 📋 fica para o exercício e o desafio.

| # | Quebra | O que se vê | Causa | Situação |
|---|---|---|---|---|
| C1 | **Save apagado** (A) | O "Continuar" do single-player leva a um estado do cooperativo, nas duas máquinas | O checkpoint grava em **cada** processo, no slot único (Cap. 56) | ✅ `HandleCheckpointReached`, só com autoridade |
| C2 | **Fatos mudos** | No convidado, a luminária de `S1.BreakersRestored` segue apagada | O subsistema do cliente não recebe os fatos | ✅ Espelho no GameState |
| C3 | **Leitura que não conta** | O convidado lê o livro de ocorrências; o log diz `AddFact(...) recusado` | A regra de fatos roda no barramento do cliente | 🔧 `ServerMarkDocumentRead`, validado pelo `UVGSectorManifest` e pela distância |
| C4 | **Sônia em dois tempos** | A mesma fala começa em momentos diferentes, ou duas vezes | Uma fila por processo, disparada por gatilhos locais | ✅ Diálogo só no servidor |
| C5 | **Resposta perdida** | A resposta de rádio do convidado não faz nada | `ChooseOption` roda numa fila que não existe | ✅ `ServerChooseDialogueOption` |
| C6 | **Lanterna de mentira** | A Presença trata o convidado de lanterna acesa como no escuro | A tag vai para a cópia **local** do personagem | ✅ `ServerFlashlightInput`; o som do interruptor é local e imediato, a luz espera um *round-trip* |
| C7 | **Lanterna sem inclinação** | O feixe do convidado aponta para o horizonte na tela do anfitrião, e o pulso dele acerta o que está à frente do corpo | A câmera que segue a rotação de controle só se atualiza na máquina que olha por ela (⚠️ confira `APawn::GetViewRotation`) | 📋 Feixe e cone por `GetBaseAimRotation()` |
| C8 | **Zona segura surda** | Na luz, a música do convidado continua de caça | `Status.Zone.Safe` não chega ao cliente | 📋 `UVGStatusTagsComponent` replicado |
| C9 | **Dois Diretores** | A música entra em pico numa máquina só | Um `UVGDirectorSubsystem` por processo | 📋 Diretor no servidor, tensão do mais tenso |
| C10 | **Leitura de quem?** | Sônia fala por cima da leitura do convidado | `IsPlayerReading()` olha só o anfitrião | 📋 Abrir e fechar o leitor viram pedidos |
| C11 | **Porta de Schrödinger** | Aberta para um, fechada e sólida para o outro | A FSM da porta não replica | 📋 Estado e início da transição replicados |
| C12 | **Morte que derruba a sessão** | O anfitrião morre, e o convidado cai; o "Continuar" do convidado é mudo | Morrer reabre o nível (Cap. 56); `GetAuthGameMode()` é nulo no cliente (Q5) | ✅ Renascer sem recarregar; 🔧 `ServerRequestRespawn` |
| C13 | **Pausa do mundo** | O menu do anfitrião congela o convidado | A pausa é do mundo, e o mundo é do servidor | ✅ `bPauseable = false` |
| C14 | **Setor sem prólogo** | Falas que pedem fatos do prólogo ficam mudas | O ramo começa no setor 1 | ✅ `StartFacts` |
| C15 | **Réplica que sobra** | Depois de ser convidado, o single-player não registra fatos | O subsistema segue em modo réplica | ✅ `EndPlay` do GameState |
| C16 | **Cena e diário só no anfitrião** | A cinemática do fim do setor toca numa tela só; o convidado não tem objetivo | Cenas (Cap. 49), quests e objetivos vivem no servidor | 📋 "Cena X começou em T", etapa e objetivos no GameState |

### Critérios de conclusão

O experimento termina quando os cinco itens forem verdade, ou quando o prazo acabar:

1. **Jogável:** o setor 1 inteiro pelos dois, três vezes, com 100 ms e 2% de perda, alternando quem hospeda.
2. **Sem cismas:** uma CVar nova, `vg.Debug.Coop`, mostra em cada tela o número de fatos, a etapa da quest e as portas abertas; ao final, as duas telas coincidem.
3. **Sem fatos órfãos:** nenhum `AddFact(...) recusado` no log do convidado no percurso final, ou cada um declarado intencional.
4. **Single-player intacto:** testes do 1.0.0 verdes no ramo; o save do single-player idêntico antes e depois de uma sessão cooperativa.
5. **Registrado:** o inventário no `DEVLOG.md`, o relatório `docs/coop/relatorio.md` e o ADR-0012 atualizado com o resultado. Continuar o cooperativo seria um ADR novo.

### O que o experimento ensina

A spec pediu o experimento para responder: como uma arquitetura pensada para um jogador muda quando o mundo é compartilhado? Classificando o inventário pelo verbo principal:

| Tipo de mudança | Quebras |
|---|---|
| Dono (quem decide) | C1, C4, C9, C12, C14, C15 |
| Espelho (como os outros veem) | C2, C8, C11, C16 |
| Pedido (como os outros pedem) | C3, C5, C6, C10 |
| Apresentação | C7 |
| Design | C13 |
| **Algoritmo** | **nenhuma** |

1. **Nenhuma quebra pediu um algoritmo novo.** `VGDialogueRules::FindPlayable`, `VGFlashlightRules::Next`, a percepção da Presença, as regras de fatos: tudo rodou no servidor sem mudança. As regras puras não sabiam em que máquina estavam, e não precisaram saber. A previsão do Interlúdio III se confirmou.
2. **O que já era dono único só precisou de uma guarda e de um espelho.** O subsistema narrativo ganhou um modo, quatro guardas e um método; o GameState, dois campos.
3. **Doeu onde decisão e apresentação estavam na mesma função**: `EnterState` (tags e feixe), `StartLine` (fila e voz), o checkpoint (lugar e save), a morte (regra e recarga), `IsPlayerReading` (uma jogadora local). Todas escondiam a suposição **um processo, uma jogadora**, e separar decisão de apresentação foi, em cada caso, a refatoração inteira.
4. **O que era derivado de fatos veio de graça.** "Salve a fonte, derive o resto" (Cap. 57) é a regra da replicação: **replique a fonte, derive o resto**. Save e rede são o mesmo problema, o estado atravessando uma fronteira: no save, o tempo; na rede, o espaço.
5. **A pergunta de design veio antes da técnica**: rádio, pausa e renascimento.

No diagrama da spec, as setas do single-player eram chamadas de função; no cooperativo, as que atravessam máquinas são só de **dois tipos** (estado replicado e pedido validado), e todas partem de um dono no servidor ou chegam a ele. A arquitetura não foi refeita: ganhou uma **fronteira**, e as fronteiras que já existiam no código (regra pura, dono único, dados) a tornaram barata.

---

## Decisões arquiteturais

1. **Release é o candidato que passa no checklist inteiro**, promovido sem recompilar; candidatos identificados por *commit*.
2. **Histórico versionado e arquivo de release** com build, símbolos, `DEVLOG.md`, licenças e versão da engine, em dois lugares.
3. **O mecânico nos *scripts***; o julgamento na lista da máquina limpa.
4. **Licenças registradas na importação**, conferidas no release.
5. **IA generativa fora por construção**, com as travas verificadas; **preservação** como critério; nenhum SDK de loja no 1.0.0.
6. **Multiplayer como ramo descartável a partir da *tag***, com prazo; nada volta para `main` sem ADR.
7. **Três verbos para estado compartilhado** (dono no servidor, espelho por estado, pedido validado), com a guarda no dono.

---

## Armadilhas

- **Recompilar o candidato aprovado "só para trocar o número"**: os símbolos deixam de servir.
- **Gerar o release com a árvore suja**: o *commit* no histórico não descreve o build.
- **Descobrir licenças na semana do release**, ou citar *testers* sem permissão.
- **Ligar `vg.GenAI.Enabled` num `.ini` "só para testar"** e esquecer.
- **Começar o cooperativo antes do release**: o produto fica para depois para sempre.
- **Guardas de autoridade nos chamadores**: cada gatilho precisaria lembrar; o dono lembra uma vez.
- **Esquecer que um `UGameInstanceSubsystem` sobrevive à sessão**: o modo réplica vaza para o single-player.
- **Replicar eventos de fatos** em vez do conjunto, ou **sincronizar a fala pelo relógio local**.
- **Salvar no cooperativo**: o slot único é sobrescrito nas duas máquinas.

---

## Exercício

**Parte 1 — o candidato (2 h).** Escreva o `Tools/release.py` e o modo candidato do `BuildVigilia.bat`. Faça cada verificação falhar uma vez: um arquivo sem *commit*, `vg.GenAI.Enabled=1` num `.ini`, um `?` no `THIRD_PARTY.md`, `bAllowGenAIInShipping = true`.

**Parte 2 — licenças e créditos (1,5 h).** Preencha o `THIRD_PARTY.md`, confira a `ST_Creditos` e peça, por escrito, a permissão de cada pessoa citada.

**Parte 3 — a máquina limpa (2 h).** Itens 10 a 14 da seção 84.3 com o Shipping, sem rede do começo ao fim. Registre e promova o candidato aprovado.

**Parte 4 — o espelho e o rádio (3 h).** No ramo, reproduza C1, C2, C4 e C5 antes de qualquer código; depois implemente o modo réplica, o `AVGCoopGameState` e o rádio no servidor.

**Parte 5 — a lanterna e o inventário (2 h).** Implemente a lanterna como pedido, o GameMode cooperativo e o teste `Vigilia.Net.Coop.Rules`, e complete o seu inventário.

---

## Desafio — o turno que chega atrasado

O ramo deixou de fora **entrar no meio da sessão**, o teste mais duro de "estado, não evento". Implemente-o e responda no `DEVLOG.md`:

1. O que funcionou sem mudança? (A previsão: fatos, luminárias, portas, a lanterna do anfitrião.)
2. O que quebrou? Pense na fala em curso, na cena já começada, na quest e no Diretor.
3. Cada quebra vem de algo replicado como **evento**, ou de algo não replicado?

---

## Uso de IA

1. **Para revisar o `THIRD_PARTY.md`:**
   > "Esta é a lista de *assets* de terceiros do meu jogo, com origem e licença (abaixo). Sem orientação jurídica: para cada linha, diga o que conferir no texto da licença (uso comercial, atribuição, redistribuição, embutir em software) e marque as ambíguas. [tabela]"

2. **Para revisar a replicação:**
   > "Revise este código de Unreal Engine 5 (GameState replicado, `OnRep`, RPC `Server` com `WithValidation`). Para cada função, diga em que máquina ela roda num *listen server*, o que acontece se o primeiro `OnRep` chegar antes do `BeginPlay`, e o que mudaria sem rede. Marque toda suposição sobre ordem de replicação que não puder confirmar no código da engine. [código]"

3. **Para prever o inventário de quebras:**
   > "Este é um jogo single-player com estes sistemas e o lugar onde cada um guarda o estado (abaixo). Vou jogá-lo com duas pessoas num *listen server*. Liste as quebras mais prováveis, com o que se vê, a causa e se a correção é de dono, de espelho, de pedido ou de design. Não proponha código. [tabela]"

**Cuidado específico:** sobre lojas e licenças, a IA afirma com segurança taxas e termos que mudam e que ela mistura entre empresas e anos; nada disso entra no checklist sem a página oficial aberta. Sobre rede, ela promete garantias de ordem entre `OnRep`, `BeginPlay` e RPCs que a engine não dá.

---

## Checklist

- [ ] Sei por que o candidato aprovado é promovido sem recompilar, e quando mudam `ProjectVersion` e `SaveVersion`.
- [ ] Tenho histórico de builds e um arquivo de release com build, símbolos, `DEVLOG.md`, licenças e versão da engine.
- [ ] Meus *scripts* verificam camadas, testes, performance, versão, árvore limpa, IA generativa, segredos e licenças.
- [ ] O Shipping passou na máquina limpa, sem rede, nos dois finais.
- [ ] Sei por que um `UGameInstanceSubsystem` precisa de um espelho num ator num jogo em rede.
- [ ] Sei separar, num sistema, dono, espelho, pedido e apresentação.
- [ ] Tenho o inventário de quebras, os critérios de conclusão e o relatório do experimento.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation): *Packaging Your Project*, *BuildCookRun*, *Networking Overview*, *Replicate Actor Properties*, *Remote Procedure Calls*, *Game Mode and Game State*.
- ***Semantic Versioning*** (semver.org) e **Creative Commons** (creativecommons.org).
- **Joshua Glazer e Sanjay Madhav, *Multiplayer Game Programming***: replicação de estado e RPCs como padrões gerais, fora da Unreal.
- **GDC Vault** (gdcvault.com): palestras de *postmortem* e de lançamento (confira os títulos lá).

---

➡️ **Próximo:** [Capítulo 85 — Postmortem](cap-85-postmortem.md)
