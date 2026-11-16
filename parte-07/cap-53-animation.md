# Capítulo 53 — Animation

## Objetivo

Ao final deste capítulo você deve conseguir:

- explicar o que são **esqueleto**, ***skeletal mesh***, ***physics asset*** e os assets de animação, e como se relacionam;
- escrever um **Animation Blueprint** com uma base em C++ que **lê** o estado do jogo sem decidir nada por ele;
- montar **state machines** de locomoção, ***blend spaces*** e ***aim offsets***;
- usar ***montages***, *slots* e ***notifies*** sem deixar o gameplay refém de uma animação;
- aplicar **IK** (pés, mãos, cabeça) onde ele compensa;
- distinguir **ragdoll**, **animação física** e reação física parcial, com GTA IV como referência;
- animar a **Presença** e os **vigias** como personagens, não só como corpos;
- montar as **mãos em primeira pessoa** com a lanterna e a arma;
- situar ***Motion Matching*** e ***Control Rig*** com a devida cautela de versão.

---

## Contexto

Até aqui, os corpos da Vigília se moveram quase sem animação. O Capítulo 30 deu ao inimigo reações por direção num `BlueprintImplementableEvent` (`OnHitReaction`) e ragdoll na morte; o Capítulo 37 deu à Presença uma telegrafia apresentada pelo Blueprint do corpo (`OnTelegraph`); o Capítulo 17 fez os passos por distância, porque a jogadora não tem corpo visível. Vários capítulos deixaram promessas:

- o Capítulo 20: "os braços e as animações de primeira pessoa entram no Capítulo 53";
- o Capítulo 5: a tensão entre **responsividade** e **fidelidade de animação** nos jogos de futebol;
- o Capítulo 15: GTA IV e a animação baseada em física;
- o Capítulo 34: "a máquina de estados do Animation Blueprint é uma FSM";
- o Capítulo 50: a Presença, com 210 cm, se curva em vãos abaixo de 220 cm;
- o Capítulo 52: os passos da Presença e dos vigias por *anim notify*.

E há uma questão de design que nenhum sistema anterior respondeu: a Presença é invencível, quase não aparece e precisa assustar **pelo jeito como se move**. A animação é a última camada da caracterização dela.

---

## 53.1 Esqueletos, malhas e assets

Um personagem animado é feito de peças que a Unreal separa em assets:

| Asset | O que é | Analogia |
|---|---|---|
| ***Skeleton*** | A hierarquia de ossos (nomes, pais, pose de referência) | O "esquema" que malhas e animações compartilham |
| ***Skeletal Mesh*** | A malha com *skinning*: cada vértice é puxado por um ou mais ossos, com pesos | O corpo |
| ***Physics Asset*** | Corpos rígidos simplificados (cápsulas, caixas) presos aos ossos, com restrições entre eles | O "esqueleto físico" do ragdoll (Cap. 30) |
| ***Animation Sequence*** | Uma animação: a transformação de cada osso ao longo do tempo | Um clipe |
| ***Blend Space*** | Animações dispostas num espaço de 1 ou 2 parâmetros, misturadas pela posição | Um "mixer" contínuo |
| ***Aim Offset*** | Um blend space aditivo de poses de mira (cima/baixo, esquerda/direita) | Mira sobre qualquer locomoção |
| ***Montage*** | Uma ou mais animações tocadas sob demanda num *slot*, com seções e notifies | Uma ação pontual |
| **Animation Blueprint** | O programa que decide a pose final a cada frame | A cola |

Uma animação pertence a um esqueleto; para usá-la em outro, é preciso ***retargeting*** (no UE5, o *IK Retargeter*; ⚠️ confira o fluxo da sua versão). Na prática, um projeto pequeno escolhe **um** esqueleto humanoide para jogadora (braços) e vigias, e um esqueleto próprio para a Presença, que precisa de proporções erradas.

**Movimento: *root motion* ou *in place*.** Numa animação *in place*, o personagem anda sem sair do lugar, e a cápsula é movida pelo `CharacterMovementComponent` (Cap. 17); a animação só acompanha a velocidade. Com ***root motion***, o deslocamento vem da animação (o osso raiz), e a cápsula segue a animação. *In place* é responsivo e sistêmico (a IA e a física mandam); *root motion* é fiel e autoral (os pés nunca deslizam, mas o movimento é o que foi animado). A Vigília usa *in place* para locomoção (a navegação manda) e *root motion* em montages específicos em que a posição importa (o recuo da Presença diante da luz).

---

## 53.2 O Animation Blueprint: ler, não decidir

O Animation Blueprint (ABP) tem duas metades:

- o ***event graph*** (ou, em C++, `NativeUpdateAnimation`), que roda no *game thread* e **coleta** dados do jogo: velocidade, se está no ar, para onde mira;
- o ***anim graph***, que **calcula a pose** com esses dados: máquinas de estado, blend spaces, montages, IK. Ele pode rodar em *worker threads*, em paralelo com o resto do jogo.

A regra de camadas da Vigília para animação é uma frase: **o ABP lê o estado do jogo; ele não é dono de estado de jogo.** A velocidade vem do `CharacterMovementComponent`; agachar vem da tag `Status.Movement.Crouched` (Cap. 23); para onde a Presença olha vem do foco do controller (Cap. 37). O ABP nunca decide se a Presença está atordoada, se a jogadora pode atirar ou se a porta abriu. Quando a animação precisa **devolver** algo ao jogo (o pé tocou o chão, o golpe chegou), ela o faz por **notifies**, que são eventos, e o jogo decide o que fazer com eles.

Por que isso importa? Porque animações são cortadas, puladas, misturadas e interrompidas o tempo todo. Gameplay que depende de "a animação terminou" quebra no primeiro corte, como as cinemáticas que "pulavam" estado no Capítulo 49.

> 🌉 **Ponte:** o ABP é uma ***view*** num padrão MVVM: lê o modelo (o estado do personagem), deriva valores de apresentação (o *view model*: velocidade, direção, alfa da mira) e desenha.
>
> 🧱 **Onde a ponte cai:** a view de uma UI não devolve dados ao modelo. A animação devolve: notifies, curvas e *root motion* alimentam o jogo. E ela roda **a cada frame**, possivelmente em outro *thread*. Por isso a coleta é feita num lugar só, no *game thread*, e o anim graph trabalha sobre cópias.

### O custo e o *thread*

O *update* da animação de cada personagem visível acontece todo frame. Com poucos personagens, como na Vigília, o custo é baixo; com dezenas, a animação vira um dos maiores itens da CPU. Três ferramentas da engine ajudam, e todas têm armadilhas:

- ***Multi-threaded animation update***: o anim graph roda fora do *game thread*. Exige que tudo que o grafo lê seja seguro para isso (no UE5, há funções marcadas como *thread safe* e o ***Property Access***; ⚠️ confira as opções do seu ABP). A base em C++ desta seção coleta tudo em `NativeUpdateAnimation`, no *game thread*, e expõe só valores simples.
- ***Update Rate Optimization*** (URO): personagens distantes atualizam a animação com menos frequência.
- **`VisibilityBasedAnimTickOption`**: não animar o que não está sendo renderizado. ⚠️ É a armadilha mais cara da Vigília: se a Presença não anima quando está fora da tela, os **notifies de passo** não disparam, e a jogadora deixa de **ouvir** a Presença atrás da parede, justamente quando o som é a única informação (Cap. 52). A Presença anima sempre.

---

## 53.3 State machines, blend spaces e aim offsets

A **máquina de estados de animação** é uma FSM (Cap. 34) com uma diferença crucial: **durante uma transição, dois estados existem ao mesmo tempo**, misturados por um tempo de *blend*. A FSM de gameplay salta; a de animação **cruza**.

```text
 LOCOMOÇÃO (vigias e Presença)

        ┌──────────────┐  bIsFalling   ┌──────────┐  !bIsFalling  ┌──────────┐
        │ Chão         │──────────────►│ No ar    │──────────────►│ Aterrissa│
        │ (blend space │               └──────────┘               └────┬─────┘
        │ por Speed e  │◄────────────────────────────────────────────────┘
        │ Direction)   │   (fim da animação ou Speed > 10)
        └──────────────┘
```

Note o que **não** está na máquina: "parado", "andando", "correndo". Eles são posições num ***blend space***, não estados. Um blend space 2D com `Speed` (0 a 600 cm/s) e `Direction` (−180° a 180°) mistura as animações de parado, andar e correr em oito direções, e o personagem passa de uma para outra continuamente. Estados são para o que é **qualitativamente** diferente (no ar, aterrissando); variações contínuas são blend spaces.

O ***aim offset*** é um blend space **aditivo**: poses de mira (olhando para cima, para baixo, para os lados) somadas por cima da locomoção. O vigia anda em qualquer direção e mira para onde a IA aponta (`SetFocus`, Cap. 37) ao mesmo tempo, sem uma animação para cada combinação.

> ⚠️ **Pés que deslizam.** Se a velocidade do blend space não corresponde à velocidade real da cápsula, os pés "patinam". Duas defesas: ajustar os valores do eixo do blend space à velocidade em que cada animação foi gravada, e usar *sync groups*/marcadores para manter os pés em fase durante as misturas (⚠️ confira as ferramentas de sincronização e de *stride warping* da sua versão).

---

## 53.4 Montages, slots e notifies

Um ***montage*** é uma animação tocada **sob demanda**, por cima da pose base, num ***slot*** (um ponto do anim graph onde montages entram: `UpperBody` só no tronco, `FullBody` no corpo todo). Tem seções (início, loop, fim), tempos de entrada e saída e notifies. É a ferramenta para ações pontuais: atirar, recarregar, a reação a um tiro, a telegrafia da Presença.

**Notifies** são eventos marcados em frames da animação ("o pé esquerdo toca o chão aqui"). ***Notify states*** marcam janelas ("o golpe pode acertar entre estes frames"). O jogo os recebe e decide.

Três regras de uso na Vigília:

1. **Quem toca o montage é o gameplay**, por uma decisão (a task da telegrafia, o componente de reação). O ABP não decide tocar montages.
2. **O gameplay nunca espera o montage terminar para manter o estado coerente.** O montage pode ser interrompido (outro montage, morte, um *stagger*). Se uma regra depende do fim, ela escuta o término **e** a interrupção (`OnMontageEnded` informa `bInterrupted`), ou usa um relógio próprio. É a lição do Capítulo 49 ("pular não é parar") em escala de um segundo.
3. **A duração do montage e a do gameplay concordam por contrato.** A telegrafia da Presença dura 1,2 s no documento de combate (Cap. 21); o montage de telegrafia tem de durar o mesmo, ou o ataque chega antes de a animação "avisar". O exercício deste capítulo verifica isso.

> 🌉 **Ponte:** montages são **comandos assíncronos** com *callbacks* de progresso (notifies) e de término (com cancelamento).
>
> 🧱 **Onde a ponte cai:** um comando assíncrono costuma ter um resultado garantido (sucesso ou erro). Um montage pode simplesmente **sumir** misturado com outro, e os notifies de uma animação que está saindo por *blend* podem ou não disparar, conforme a configuração. Nunca ponha uma regra de jogo crítica num notify sem um caminho alternativo.

---

## 53.5 IK

***Inverse kinematics*** (IK) resolve a pergunta contrária à animação: em vez de "girando estes ossos, onde a mão chega?", "para a mão chegar **aqui**, como giro os ossos?". Três usos que compensam numa Vigília:

- **Pés no chão** (*foot IK*): em escadas e pisos irregulares, um *trace* sob cada pé e um IK de duas articulações (*two-bone IK*, nós de *leg IK*) assentam o pé na superfície real. Sem ele, os vigias flutuam nos degraus da subestação.
- **Mãos na arma**: a arma em primeira pessoa é posicionada pelo componente de armas (Caps. 26 e 29: posição de mira, coice, balanço); a mão direita **segue a arma** por IK até o *socket* de empunhadura. A arma continua dona da posição; a mão só acompanha.
- **Cabeça que olha** (*look-at*): a cabeça da Presença gira em direção à jogadora quando a IA está focada nela. É barato e é, talvez, a animação mais assustadora do jogo: o corpo parado, e a cabeça acompanhando.

O ***Control Rig*** é o sistema de *rigging* e animação procedural dentro da Unreal: um grafo que manipula ossos e controles, usado tanto para animar no editor (em Sequencer, Cap. 49) quanto em tempo de execução (IK de corpo inteiro, ajustes procedurais). ⚠️ Os recursos de Control Rig (incluindo o *Full Body IK*) evoluíram muito entre as versões do UE5; para a Vigília, os nós de IK do anim graph bastam, e o Control Rig fica como caminho para quando um ajuste procedural crescer além deles.

---

## 53.6 Física na animação

Há três níveis de "física no corpo", e eles respondem a perguntas diferentes:

| Nível | O que acontece | Quando usar | Na Vigília |
|---|---|---|---|
| **Ragdoll** | O corpo inteiro passa à simulação; a animação para | Morte, nocaute | Vigias, na morte (Cap. 30) |
| **Reação física parcial** | Parte do corpo (do tronco para cima) simula por um instante, misturada com a animação por um peso que decai | Tiros, empurrões, impactos | Vigias, a cada acerto |
| **Animação física** (*physical animation*) | Os corpos simulados são puxados por "motores" em direção à pose animada: o corpo anima **e** reage | Personagens que tropeçam, se apoiam, resistem | Combinada com a anterior, para o tronco não ficar mole |

A Unreal oferece as peças: no `USkeletalMeshComponent`, simular os corpos abaixo de um osso (`SetAllBodiesBelowSimulatePhysics`) e misturar a física com a animação por um peso (`SetAllBodiesBelowPhysicsBlendWeight`); e o `UPhysicalAnimationComponent`, que aplica os motores (`ApplyPhysicalAnimationSettingsBelow`).

A Presença é a exceção deliberada: **ela não tem física no corpo**. Ela é invencível, e um corpo que balança com impactos lê como "atingível". A reação dela à luz é um montage autoral, com *root motion*: um recuo que parece decisão, não empurrão.

> 🌉 **Ponte:** a reação física parcial é um ***circuit breaker*** com recuperação gradual: o sistema (a animação) cede o controle a um regime de emergência (a física) e o retoma aos poucos, com um peso que decai.
>
> 🧱 **Onde a ponte cai:** o *circuit breaker* existe para proteger; aqui, ceder o controle é o **objetivo**. A graça está nos 300 ms em que o corpo não obedece à animação, e o peso que decai é desenhado para parecer físico, não para ser seguro.

---

## 53.7 A Presença e os vigias

### A Presença: animação como caracterização

A Presença aparece pouco, e por isso cada aparição precisa dizer "isto não é humano" sem uma palavra. As ferramentas são todas de animação:

- **Proporções erradas** no esqueleto próprio: membros longos, 210 cm.
- **Cadência irregular**: a taxa de reprodução da locomoção varia levemente (±15%), com pausas curtas. Um humano anda num ritmo; ela não.
- **Imobilidade**: o *idle* de espreita é quase uma pose congelada, com micro-movimentos raros. Quietude é mais assustadora que movimento.
- **A cabeça** que segue a jogadora por *look-at* (seção 53.5).
- **O corpo que se dobra** para passar em vãos baixos (Cap. 50): um *trace* para cima, poucas vezes por segundo, alimenta um alfa de "curvada" no ABP. Ela não abaixa como uma pessoa agacha; ela **dobra**.
- **Telegrafia** (1,2 s, Cap. 21) com um montage de corpo inteiro que sempre começa igual: a jogadora aprende a reconhecê-lo.

A **primeira aparição**, a silhueta do susto (Caps. 49–50), é uma **pose estática** do mesmo esqueleto, num *spawnable* da cena. Ela não anda nem respira: está lá, e some. A animação mínima é a máxima.

### Os vigias: animação como legibilidade

Os vigias são humanos e armados, e a animação deles tem outra função: **legibilidade tática**. A jogadora precisa ler, de relance, o que um vigia vai fazer.

- Locomoção com blend space e *aim offset*: para onde ele anda e para onde mira são informações independentes.
- Uma pose de cobertura (Cap. 41) distinta de "parado": a jogadora sabe que ele está protegido.
- O gesto de recarregar visível e um pouco longo: a janela de vulnerabilidade (Cap. 21) tem de ser **vista**.
- Reações a acertos por direção (montage, Cap. 30) somadas à reação física parcial: o acerto **se vê** no corpo, que é o melhor *hit marker* que existe.
- Morte com ragdoll e o impulso do golpe fatal (Cap. 30).

---

## 53.8 Mãos em primeira pessoa

Helena não tem corpo visível (Cap. 17). Ela tem **braços**: uma malha só de braços presa à câmera, que só a dona vê. É a forma clássica de FPS, e na Vigília ela segura duas coisas:

- **Mão esquerda: a lanterna, sempre.** Como em Alan Wake, a lanterna e a arma convivem; uma arma de duas mãos seria incompatível com a lanterna, e por isso a Vigília só tem armas de uma mão (a pistola de sinalização e a pistola dos vigias).
- **Mão direita: a arma**, posicionada pelo componente de armas e alcançada por IK.

Três problemas técnicos típicos de primeira pessoa, e as respostas:

1. **Os braços atravessam paredes.** A câmera fica a ~20 cm da parede, e a arma, a 40 cm à frente. Soluções clássicas: um campo de visão separado para os braços (desenhados com outro FOV e sem atravessar a geometria; ⚠️ versões recentes do UE5 trouxeram suporte nativo a renderização de primeira pessoa com FOV próprio, confira a sua), ou recolher a arma quando há uma parede perto (um *trace* curto e uma pose "arma baixa").
2. **Sombras estranhas.** A lanterna (Cap. 51) está na câmera; os braços e a arma estão na frente dela. Se projetarem sombra, uma mão gigante cobre metade da parede iluminada. Os braços **não projetam sombra** da lanterna.
3. **O feixe acompanha a mira, não a mão.** O componente de luz da lanterna continua preso à câmera (Cap. 51): a mira, a percepção e o cone da sobrecarga usam a direção da câmera. A lanterna **na mão** é a malha, com o balanço do braço; um pequeno atraso do feixe em relação à câmera pode dar vida sem tirar precisão (desafio).

---

## 53.9 Motion Matching e o que fica de fora

***Motion Matching*** é uma técnica de animação em que, em vez de máquinas de estado e blend spaces desenhados à mão, o sistema procura, a cada poucos frames, o trecho de um grande banco de animações cuja pose e trajetória mais se parecem com o que o personagem está fazendo e vai fazer. O resultado é movimento muito natural e responsivo, ao custo de **muitos dados** (horas de captura de movimento organizadas) e de ferramentas próprias.

Na Unreal, o Motion Matching chegou pelo plugin *Pose Search*, e a Epic publicou projetos de exemplo de animação de jogo construídos sobre ele. ⚠️ O estado do recurso (experimental, beta, pronto para produção) mudou entre as versões 5.x; confira o da sua antes de planejar com ele.

**Decisão para a Vigília:** fica de fora. São dois tipos de IA, com locomoção simples, e um orçamento de animação de um projeto individual. Máquinas de estado e blend spaces cobrem tudo, e cada animação é escolhida à mão, o que, para a Presença, é uma vantagem: o movimento dela **deve** ser autoral, não natural.

---

## Estudos de caso

### GTA IV — o corpo que reage

**[FATO PÚBLICO]** Como visto no Capítulo 15, *Grand Theft Auto IV* (Rockstar, 2008) incorporou o ***euphoria***, da NaturalMotion, para animação de personagens baseada em física: os personagens tentam se equilibrar, se apoiar e se proteger quando empurrados, atropelados ou baleados, em vez de tocar só animações gravadas. **[FATO PÚBLICO, observável jogando]** Pedestres tropeçam em degraus, se agarram a carros, caem de jeitos diferentes a cada vez.

**[INFERÊNCIA]** O que o jogador percebe como "vida" é a **variedade não roteirizada** das reações: o mesmo tiro produz uma queda diferente conforme a pose, o chão e o que está em volta. É a cadeia da spec, "sistemas de baixo nível viram experiência", na sua forma mais pura: física, animação e IA do corpo trabalhando juntas. Os detalhes de como a RAGE e o euphoria se integram não são públicos.

**Lição para a Vigília:** a reação física parcial dos vigias é a versão de bolso da mesma ideia: um montage por direção dá a leitura, e 300 ms de física misturada dão a variedade. Nenhum acerto parece igual ao anterior, e isso faz o combate curto do setor 2 parecer mais "pesado" do que o número de vigias sugere.

### PES/FIFA — responsividade contra fidelidade

**[FATO PÚBLICO]** A EA divulgou, para *FIFA 22*, a tecnologia "HyperMotion", baseada em captura de movimento de partidas com vários jogadores ao mesmo tempo e em aprendizado de máquina para gerar animações. **[FATO PÚBLICO]** O *eFootball* (ex-PES) roda na Unreal Engine desde 2021.

**[INFERÊNCIA]** O Capítulo 5 deixou a tensão em aberto: animações longas e fiéis atrasam a resposta ao comando; animações cortadas cedo respondem rápido e parecem "arcade". Toda a evolução recente da animação em jogos esportivos pode ser lida como tentativa de ter as duas coisas: bancos enormes de movimento (onde sempre há uma animação que **começa** perto da pose atual) e técnicas de seleção, como o *motion matching*, que trocam de animação a qualquer momento sem um corte visível. O jogador sente "responde e parece real". Quanto de cada técnica cada jogo usa não é público em detalhe.

**Lição para a Vigília:** a jogadora não tem corpo visível, então o dilema aparece nos braços. Recarregar é um montage de ~2 s, e a jogadora precisa poder **cancelá-lo** (correr, trocar de arma, acender a lanterna) sem esperar o fim; a recarga só conta se chegar ao notify de "pente encaixado". Fidelidade quando ela não está com pressa; resposta quando está.

### Outlast — o corpo do protagonista

**[FATO PÚBLICO, observável jogando]** Em *Outlast* (Red Barrels, 2013), o protagonista tem corpo inteiro em primeira pessoa: é possível ver pernas e mãos, e as mãos aparecem apoiadas em paredes e batentes ao espiar por cantos, ao correr e ao abrir portas.

**[INFERÊNCIA]** O corpo visível faz duas coisas para o terror: **ancora** a jogadora no espaço (ela tem tamanho, peso, presença física) e mostra **vulnerabilidade** (mãos tremendo, apoio na parede, ninguém armado). É caro: a câmera presa à cabeça de um corpo animado exige cuidado para não causar enjoo e para manter a mira estável.

**Lição para a Vigília:** a Vigília não adota corpo inteiro (a abordagem B, abaixo), mas aproveita a ideia nos braços: a mão da lanterna treme levemente quando a ameaça sobe (`UVGThreatSubsystem`), e a mão livre toca o batente ao passar por portas estreitas. Pequenos gestos de vulnerabilidade, sem o custo do corpo inteiro.

---

## Comparação com o desenvolvimento tradicional

| Conceito | O que você conhece | Onde a analogia cai |
|---|---|---|
| ABP que lê o estado | *View* em MVVM | A view devolve dados (notifies, curvas, *root motion*) e roda todo frame, talvez em outro *thread* |
| State machine de animação | FSM | Durante a transição, os dois estados coexistem (*blend*) |
| Montage com notifies | Comando assíncrono com *callbacks* | Pode sumir num *blend*; notifies não são garantia |
| Reação física parcial | *Circuit breaker* com recuperação gradual | Ceder o controle é o objetivo |
| Retargeting | Adaptador entre esquemas | Proporções diferentes produzem artefatos que nenhum adaptador esconde |

---

## Unreal Engine: o que existe

- **Assets**: Skeleton, Skeletal Mesh, Physics Asset, Animation Sequence, Blend Space (1D/2D), Aim Offset, Animation Montage, Pose Asset, *IK Rig* e *IK Retargeter*.
- **Animation Blueprint** com base C++ (`UAnimInstance`: `NativeInitializeAnimation`, `NativeUpdateAnimation`; ⚠️ e, em versões UE5, `NativeThreadSafeUpdateAnimation` para trabalho fora do *game thread*).
- **Nós do anim graph**: *State Machine*, *Blend Space Player*, *Layered blend per bone*, *Slot*, *Two Bone IK*, *Look At*, *Leg IK* e outros (⚠️ nomes e disponibilidade por versão e por plugin).
- **Montages**: `ACharacter::PlayAnimMontage`/`StopAnimMontage`; `UAnimInstance::Montage_Play`, `Montage_Stop`, `OnMontageEnded`, `OnMontageBlendingOut`.
- **Notifies**: `UAnimNotify` e `UAnimNotifyState` (C++ ou Blueprint).
- **Física**: Physics Asset, `SetAllBodiesBelowSimulatePhysics`, `SetAllBodiesBelowPhysicsBlendWeight`, `UPhysicalAnimationComponent`.
- **Otimização**: multi-threaded update, URO, `VisibilityBasedAnimTickOption`, LODs de animação.
- **Control Rig** e **Motion Matching** (*Pose Search*), com a cautela de versão das seções 53.5 e 53.9.

O que a engine **não** oferece: a decisão de **o que** a animação deve comunicar. A Presença "errada" e o vigia "legível" são design.

---

## Abordagens: o corpo em primeira pessoa

| Critério | **A. Só braços (malha de braços na câmera)** | B. Corpo inteiro, câmera na cabeça (Outlast) | C. Sem braços (arma e lanterna flutuando) |
|---|---|---|---|
| **Presença física** | Média | **Alta** | Baixa |
| **Controle da câmera e da mira** | **Total** | Difícil (a cabeça anima) | Total |
| **Risco de enjoo** | **Baixo** | Alto, se mal feito | Baixo |
| **Custo de animação** | **Médio** (braços: idle, andar, recarregar, gestos) | Alto (corpo inteiro × todas as ações) | Baixo |
| **Sombra e reflexo do corpo** | Ausentes (decisão) | Corretos | Ausentes |
| **Adequação à Vigília** | **Sim** | Excesso para o escopo | Quebra a imersão que o terror exige |

**Decisão: A**, com gestos de vulnerabilidade nos braços (o tremor da mão da lanterna, o apoio no batente), o que traz parte do que B oferece pelo custo de A.

---

## Implementação

### 1. Regras puras

```cpp
// Source/Vigilia/AI/VGAnimRules.h
#pragma once

#include "CoreMinimal.h"

namespace VGAnimRules
{
    /** Direção da locomoção em graus [-180, 180]: 0 = para a frente, 90 = para a direita. */
    float LocomotionDirection(const FVector& Velocity, const FRotator& ActorRotation);

    /** Peso da física na reação parcial: começa no pico (o impacto) e cai suavemente a 0 em Duration. */
    float FlinchWeight(float Elapsed, float Duration, float Peak);
}
```

```cpp
// Source/Vigilia/AI/VGAnimRules.cpp
#include "AI/VGAnimRules.h"

float VGAnimRules::LocomotionDirection(const FVector& Velocity, const FRotator& ActorRotation)
{
    if (Velocity.SizeSquared2D() < KINDA_SMALL_NUMBER)
    {
        return 0.0f;
    }
    return FRotator::NormalizeAxis(Velocity.Rotation().Yaw - ActorRotation.Yaw);
}

float VGAnimRules::FlinchWeight(float Elapsed, float Duration, float Peak)
{
    if (Duration <= 0.0f || Elapsed >= Duration)
    {
        return 0.0f;
    }
    const float T = FMath::Clamp(Elapsed / Duration, 0.0f, 1.0f);
    return Peak * (1.0f - FMath::SmoothStep(0.0f, 1.0f, T));
}
```

### 2. A base do Animation Blueprint

```cpp
// Source/Vigilia/AI/VGAnimInstance.h
#pragma once

#include "CoreMinimal.h"
#include "Animation/AnimInstance.h"
#include "VGAnimInstance.generated.h"

class ACharacter;

/**
 * Base dos ABPs de vigias e da Presença: LÊ o estado do jogo no game thread e expõe valores simples
 * para o anim graph. Não é dona de nenhum estado de jogo.
 */
UCLASS()
class VIGILIA_API UVGAnimInstance : public UAnimInstance
{
    GENERATED_BODY()

protected:
    virtual void NativeInitializeAnimation() override;
    virtual void NativeUpdateAnimation(float DeltaSeconds) override;

    UPROPERTY(BlueprintReadOnly, Category = "Vigilia|Anim")
    float Speed = 0.0f;

    UPROPERTY(BlueprintReadOnly, Category = "Vigilia|Anim")
    float Direction = 0.0f;

    UPROPERTY(BlueprintReadOnly, Category = "Vigilia|Anim")
    bool bIsFalling = false;

    UPROPERTY(BlueprintReadOnly, Category = "Vigilia|Anim")
    bool bIsCrouching = false;

    /** Mira relativa ao corpo (aim offset dos vigias). */
    UPROPERTY(BlueprintReadOnly, Category = "Vigilia|Anim")
    float AimPitch = 0.0f;

    UPROPERTY(BlueprintReadOnly, Category = "Vigilia|Anim")
    float AimYaw = 0.0f;

    /** Para onde a cabeça olha (o foco do controller de IA) e com que peso. */
    UPROPERTY(BlueprintReadOnly, Category = "Vigilia|Anim")
    FVector LookAtLocation = FVector::ZeroVector;

    UPROPERTY(BlueprintReadOnly, Category = "Vigilia|Anim")
    float LookAtAlpha = 0.0f;

    /** 0 = em pé, 1 = dobrada (teto baixo). Só calculado com bTrackCeiling. */
    UPROPERTY(BlueprintReadOnly, Category = "Vigilia|Anim")
    float LowCeilingAlpha = 0.0f;

    /** Presença: verifica o teto acima e dobra o corpo em vãos baixos (Cap. 50). */
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Anim")
    bool bTrackCeiling = false;

    /** Altura livre abaixo da qual o corpo dobra, medida a partir do chão. */
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Anim", meta = (EditCondition = "bTrackCeiling"))
    float CeilingClearance = 220.0f;

private:
    UPROPERTY(Transient)
    TObjectPtr<ACharacter> Character;

    float CeilingCheckAccumulator = 0.0f;
    bool bLowCeiling = false;
};
```

```cpp
// Source/Vigilia/AI/VGAnimInstance.cpp
#include "AI/VGAnimInstance.h"

#include "AIController.h"
#include "AI/VGAnimRules.h"
#include "Components/CapsuleComponent.h"
#include "Engine/World.h"
#include "GameFramework/Character.h"
#include "GameFramework/CharacterMovementComponent.h"

void UVGAnimInstance::NativeInitializeAnimation()
{
    Super::NativeInitializeAnimation();
    Character = Cast<ACharacter>(TryGetPawnOwner());
}

void UVGAnimInstance::NativeUpdateAnimation(float DeltaSeconds)
{
    Super::NativeUpdateAnimation(DeltaSeconds);
    if (!Character)
    {
        return; // no editor (preview) não há personagem
    }

    const FVector Velocity = Character->GetVelocity();
    Speed = Velocity.Size2D();
    Direction = VGAnimRules::LocomotionDirection(Velocity, Character->GetActorRotation());
    const UCharacterMovementComponent* Movement = Character->GetCharacterMovement();
    bIsFalling = Movement && Movement->IsFalling();
    bIsCrouching = Movement && Movement->IsCrouching();

    const FRotator Aim = (Character->GetBaseAimRotation() - Character->GetActorRotation()).GetNormalized();
    AimPitch = Aim.Pitch;
    AimYaw = Aim.Yaw;

    // A cabeça segue o foco da IA (SetFocus, Cap. 37): nenhuma informação nova, só a que já existe.
    float TargetLookAlpha = 0.0f;
    if (const AAIController* AI = Cast<AAIController>(Character->GetController()))
    {
        if (const AActor* Focus = AI->GetFocusActor())
        {
            LookAtLocation = Focus->GetActorLocation() + FVector(0.0f, 0.0f, 60.0f); // ~altura dos olhos
            TargetLookAlpha = 1.0f;
        }
    }
    LookAtAlpha = FMath::FInterpTo(LookAtAlpha, TargetLookAlpha, DeltaSeconds, 3.0f);

    if (bTrackCeiling)
    {
        CeilingCheckAccumulator += DeltaSeconds;
        if (CeilingCheckAccumulator >= 0.2f) // 5 Hz basta: vãos não aparecem de repente
        {
            CeilingCheckAccumulator = 0.0f;
            const float HalfHeight = Character->GetCapsuleComponent()->GetScaledCapsuleHalfHeight();
            const FVector Feet = Character->GetActorLocation() - FVector(0.0f, 0.0f, HalfHeight);
            FHitResult Hit;
            FCollisionQueryParams Params(SCENE_QUERY_STAT(VGCeiling), false, Character);
            bLowCeiling = Character->GetWorld()->LineTraceSingleByChannel(
                Hit, Character->GetActorLocation(), Feet + FVector(0.0f, 0.0f, CeilingClearance), ECC_Visibility, Params);
        }
        LowCeilingAlpha = FMath::FInterpTo(LowCeilingAlpha, bLowCeiling ? 1.0f : 0.0f, DeltaSeconds, 4.0f);
    }
}
```

O anim graph de cada ABP usa esses valores: o blend space com `Speed`/`Direction`, a máquina de estados com `bIsFalling`, o aim offset com `AimPitch`/`AimYaw`, um nó de *look-at* na cabeça com `LookAtLocation`/`LookAtAlpha`, e, na Presença, um *blend* por `LowCeilingAlpha` entre a locomoção normal e a "dobrada" (ou um aditivo de dobra). A variação de cadência da Presença é feita no grafo, com a taxa de reprodução da locomoção modulada por uma curva ou um valor aleatório que muda a cada passo.

### 3. Reação a acertos: dados e física parcial

```cpp
// Source/Vigilia/Combat/VGHitReactionData.h
#pragma once

#include "CoreMinimal.h"
#include "AI/VGEnemyCharacter.h" // EVGHitDirection (Cap. 30)
#include "Engine/DataAsset.h"
#include "VGHitReactionData.generated.h"

class UAnimMontage;

/** Montages de reação por direção (Cap. 30). Um asset por tipo de corpo. */
UCLASS(BlueprintType)
class VIGILIA_API UVGHitReactionData : public UPrimaryDataAsset
{
    GENERATED_BODY()

public:
    UPROPERTY(EditDefaultsOnly, Category = "HitReaction")
    TMap<EVGHitDirection, TObjectPtr<UAnimMontage>> Montages;

    /** Montage de "stagger" (Cap. 30), mais longo; tem prioridade sobre o direcional. */
    UPROPERTY(EditDefaultsOnly, Category = "HitReaction")
    TObjectPtr<UAnimMontage> Stagger;

    UAnimMontage* Pick(EVGHitDirection Direction, bool bStaggered) const
    {
        if (bStaggered && Stagger)
        {
            return Stagger;
        }
        const TObjectPtr<UAnimMontage>* Found = Montages.Find(Direction);
        return Found ? Found->Get() : nullptr;
    }
};
```

```cpp
// Source/Vigilia/Combat/VGPhysicalReactionComponent.h
#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "PhysicsEngine/PhysicalAnimationComponent.h"
#include "VGPhysicalReactionComponent.generated.h"

class USkeletalMeshComponent;

/**
 * Reação física parcial: do RootBone para baixo, o corpo simula por Duration, puxado de volta
 * à animação por motores (UPhysicalAnimationComponent) e por um peso que decai (VGAnimRules).
 * Relógio: DeltaTime do componente (tempo de jogo: o hitstop congela o tranco junto).
 */
UCLASS(ClassGroup = (Vigilia), meta = (BlueprintSpawnableComponent))
class VIGILIA_API UVGPhysicalReactionComponent : public UActorComponent
{
    GENERATED_BODY()

public:
    UVGPhysicalReactionComponent();

    UFUNCTION(BlueprintCallable, Category = "Vigilia|Anim")
    void Flinch(FName HitBone, FVector Impulse);

    /** Desliga para sempre (a morte: o ragdoll completo assume, Cap. 30). */
    UFUNCTION(BlueprintCallable, Category = "Vigilia|Anim")
    void Stop();

protected:
    virtual void BeginPlay() override;
    virtual void TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction) override;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Anim")
    FName RootBone = TEXT("spine_01");

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Anim", meta = (ClampMin = "0.0", ClampMax = "1.0"))
    float PeakWeight = 0.6f;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Anim", meta = (ClampMin = "0.05"))
    float Duration = 0.35f;

    /** Força dos motores que puxam o tronco de volta à pose animada. */
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Anim")
    FPhysicalAnimationData Motors;

private:
    void EndFlinch();

    UPROPERTY(Transient)
    TObjectPtr<USkeletalMeshComponent> Mesh;

    UPROPERTY(Transient)
    TObjectPtr<UPhysicalAnimationComponent> PhysicalAnimation;

    float Elapsed = 0.0f;
    bool bActive = false;
    bool bStopped = false;
};
```

```cpp
// Source/Vigilia/Combat/VGPhysicalReactionComponent.cpp
#include "Combat/VGPhysicalReactionComponent.h"

#include "AI/VGAnimRules.h"
#include "Components/SkeletalMeshComponent.h"
#include "GameFramework/Character.h"

UVGPhysicalReactionComponent::UVGPhysicalReactionComponent()
{
    PrimaryComponentTick.bCanEverTick = true;
    PrimaryComponentTick.bStartWithTickEnabled = false;
    Motors.bIsLocalSimulation = true;
    Motors.OrientationStrength = 1000.0f;
    Motors.AngularVelocityStrength = 100.0f;
}

void UVGPhysicalReactionComponent::BeginPlay()
{
    Super::BeginPlay();
    const ACharacter* Character = Cast<ACharacter>(GetOwner());
    Mesh = Character ? Character->GetMesh() : nullptr;
    if (!Mesh)
    {
        return;
    }
    PhysicalAnimation = NewObject<UPhysicalAnimationComponent>(GetOwner(), TEXT("VGPhysicalAnimation"));
    PhysicalAnimation->RegisterComponent();
    PhysicalAnimation->SetSkeletalMeshComponent(Mesh);
    PhysicalAnimation->ApplyPhysicalAnimationSettingsBelow(RootBone, Motors, /*bIncludeSelf=*/true);
}

void UVGPhysicalReactionComponent::Flinch(FName HitBone, FVector Impulse)
{
    if (bStopped || !Mesh)
    {
        return;
    }
    if (!bActive)
    {
        Mesh->SetAllBodiesBelowSimulatePhysics(RootBone, true, /*bIncludeSelf=*/true);
        bActive = true;
        SetComponentTickEnabled(true);
    }
    Elapsed = 0.0f; // um acerto novo recomeça o tranco
    Mesh->AddImpulse(Impulse, HitBone, /*bVelChange=*/true); // independente da massa: o mesmo tiro, o mesmo tranco
}

void UVGPhysicalReactionComponent::TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction)
{
    Super::TickComponent(DeltaTime, TickType, ThisTickFunction);
    Elapsed += DeltaTime;
    const float Weight = VGAnimRules::FlinchWeight(Elapsed, Duration, PeakWeight);
    Mesh->SetAllBodiesBelowPhysicsBlendWeight(RootBone, Weight, /*bSkipCustomPhysicsType=*/false, /*bIncludeSelf=*/true);
    if (Elapsed >= Duration)
    {
        EndFlinch();
    }
}

void UVGPhysicalReactionComponent::EndFlinch()
{
    bActive = false;
    SetComponentTickEnabled(false);
    Mesh->SetAllBodiesBelowSimulatePhysics(RootBone, false, /*bIncludeSelf=*/true);
    Mesh->SetAllBodiesBelowPhysicsBlendWeight(RootBone, 0.0f, false, true);
}

void UVGPhysicalReactionComponent::Stop()
{
    if (bActive && Mesh)
    {
        // Não desliga a simulação: o ragdoll vai assumir o corpo inteiro logo em seguida.
        bActive = false;
        SetComponentTickEnabled(false);
    }
    bStopped = true;
}
```

> ⚠️ **Para a física parcial funcionar**, a malha precisa ter colisão de física habilitada (*QueryAndPhysics*) e um Physics Asset com corpos e restrições razoáveis no tronco e nos braços; e os corpos simulados não devem colidir com a própria cápsula do personagem (ajuste as respostas de colisão, ou o tronco "explode" contra ela). Os nomes de ossos (`spine_01`) dependem do seu esqueleto. Confira também os campos de `FPhysicalAnimationData` na sua versão.

🔁 No `AVGEnemyCharacter` (Cap. 30), a reação passa a ter uma parte em C++ antes do evento de Blueprint, e a morte desliga a física parcial antes do ragdoll:

```cpp
// VGEnemyCharacter.h (adições)
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Enemy")
    TObjectPtr<class UVGHitReactionData> HitReactions;

    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
    TObjectPtr<class UVGPhysicalReactionComponent> PhysicalReaction;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Enemy", meta = (ClampMin = "0.0"))
    float FlinchImpulse = 250.0f; // cm/s de mudança de velocidade no osso atingido

    /** Falso na Presença: ela não tem física no corpo (seção 53.6). */
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Enemy")
    bool bPhysicalHitReactions = true;

// VGEnemyCharacter.cpp, onde o Cap. 30 chamava OnHitReaction(...):
    const EVGHitDirection Direction = ComputeHitDirection(LastShotDirection);
    if (UAnimMontage* Montage = HitReactions ? HitReactions->Pick(Direction, bStagger) : nullptr)
    {
        PlayAnimMontage(Montage); // a leitura: o corpo "conta" de onde veio o tiro
    }
    if (bPhysicalHitReactions)
    {
        PhysicalReaction->Flinch(LastHitBone, LastShotDirection.GetSafeNormal() * FlinchImpulse); // a variedade
    }
    OnHitReaction(Direction, LastHitBone, bStagger); // som e partículas continuam no Blueprint

// e em HandleDied, ANTES de StartRagdoll():
    PhysicalReaction->Stop();
```

O `PhysicalReaction` é criado no construtor do `AVGEnemyCharacter` com `CreateDefaultSubobject`. No Blueprint da Presença, `HitReactions` fica vazio e `bPhysicalHitReactions` falso, por decisão (seção 53.6).

### 4. O passo por notify

```cpp
// Source/Vigilia/AI/VGAnimNotify_Footstep.h
#pragma once

#include "CoreMinimal.h"
#include "Animation/AnimNotifies/AnimNotify.h"
#include "VGAnimNotify_Footstep.generated.h"

/**
 * Passo de personagem animado (vigias, Presença): descobre a superfície sob o pé e toca o
 * FootstepSound do material (Cap. 52). NÃO emite ruído para a IA: são passos para a jogadora ouvir.
 */
UCLASS(meta = (DisplayName = "VG Footstep"))
class VIGILIA_API UVGAnimNotify_Footstep : public UAnimNotify
{
    GENERATED_BODY()

public:
    virtual void Notify(USkeletalMeshComponent* MeshComp, UAnimSequenceBase* Animation,
                        const FAnimNotifyEventReference& EventReference) override;

protected:
    UPROPERTY(EditAnywhere, Category = "Footstep")
    FName FootBone = TEXT("foot_l");

    UPROPERTY(EditAnywhere, Category = "Footstep", meta = (ClampMin = "0.0"))
    float Loudness = 0.5f;
};
```

```cpp
// Source/Vigilia/AI/VGAnimNotify_Footstep.cpp
#include "AI/VGAnimNotify_Footstep.h"

#include "Core/VGAudioRules.h"
#include "Combat/VGPhysicalMaterial.h"
#include "Components/SkeletalMeshComponent.h"
#include "Kismet/GameplayStatics.h"

void UVGAnimNotify_Footstep::Notify(USkeletalMeshComponent* MeshComp, UAnimSequenceBase* Animation,
                                    const FAnimNotifyEventReference& EventReference)
{
    Super::Notify(MeshComp, Animation, EventReference);
    UWorld* World = MeshComp ? MeshComp->GetWorld() : nullptr;
    if (!World || !World->IsGameWorld())
    {
        return; // no editor de animação, sem som de jogo (a prévia tem os próprios sons)
    }
    const FVector Foot = MeshComp->GetSocketLocation(FootBone);
    FHitResult Hit;
    FCollisionQueryParams Params(SCENE_QUERY_STAT(VGFootstepNotify), false, MeshComp->GetOwner());
    Params.bReturnPhysicalMaterial = true;
    if (!World->LineTraceSingleByChannel(Hit, Foot + FVector(0, 0, 20), Foot - FVector(0, 0, 40), ECC_Visibility, Params))
    {
        return;
    }
    const UVGPhysicalMaterial* Material = Cast<UVGPhysicalMaterial>(Hit.PhysMaterial.Get());
    if (Material && Material->FootstepSound)
    {
        const float FinalLoudness = Loudness * Material->NoiseMultiplier; // a mesma conta da jogadora (Cap. 52)
        UGameplayStatics::PlaySoundAtLocation(World, Material->FootstepSound, Hit.ImpactPoint,
                                              VGAudioRules::FootstepVolume(FinalLoudness));
    }
}
```

⚠️ A assinatura de `UAnimNotify::Notify` com `FAnimNotifyEventReference` é a do UE5; a antiga, sem esse parâmetro, foi depreciada. Confira a da sua versão.

### 5. O teste

```cpp
// Source/Vigilia/Tests/VGAnimRulesTest.cpp
#include "AI/VGAnimRules.h"
#include "Misc/AutomationTest.h"

#if WITH_DEV_AUTOMATION_TESTS

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FVGAnimRulesTest, "Vigilia.Animation.Rules",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ProductFilter)

bool FVGAnimRulesTest::RunTest(const FString& Parameters)
{
    const FRotator FacingX(0.0f, 0.0f, 0.0f);
    TestEqual(TEXT("Para a frente = 0"),   VGAnimRules::LocomotionDirection(FVector(100, 0, 0), FacingX), 0.0f);
    TestEqual(TEXT("Para a direita = 90"), VGAnimRules::LocomotionDirection(FVector(0, 100, 0), FacingX), 90.0f);
    TestEqual(TEXT("Parado = 0"),          VGAnimRules::LocomotionDirection(FVector::ZeroVector, FacingX), 0.0f);
    TestTrue(TEXT("Para trás = ±180"),
        FMath::IsNearlyEqual(FMath::Abs(VGAnimRules::LocomotionDirection(FVector(-100, 0, 0), FacingX)), 180.0f));

    TestEqual(TEXT("Tranco começa no pico"), VGAnimRules::FlinchWeight(0.0f, 0.35f, 0.6f), 0.6f);
    TestEqual(TEXT("Tranco termina em 0"),   VGAnimRules::FlinchWeight(0.35f, 0.35f, 0.6f), 0.0f);
    float Previous = 1.0f;
    for (float T = 0.0f; T <= 0.4f; T += 0.05f)
    {
        const float W = VGAnimRules::FlinchWeight(T, 0.35f, 0.6f);
        TestTrue(FString::Printf(TEXT("Tranco nunca cresce (t=%.2f)"), T), W <= Previous);
        Previous = W;
    }
    return true;
}

#endif
```

### Explicação das decisões

- **A base em C++ coleta, o grafo desenha.** Toda leitura do jogo acontece em `NativeUpdateAnimation`, no *game thread*, e vira um valor simples. O anim graph pode ir para *worker threads* sem risco.
- **Nenhum estado novo para animar.** O *look-at* usa o foco do controller (Cap. 37), o agachar usa o CMC, a direção vem da velocidade. Se a animação precisasse de um estado que o jogo não tem, isso seria um sinal de que a animação está decidindo algo.
- **Teto por *trace* a 5 Hz**, não por volumes no nível: funciona em qualquer vão, inclusive nos dos setores 2 e 3, sem trabalho de level design.
- **Reação = leitura (montage) + variedade (física)**. O montage por direção garante que a jogadora entenda; os 300 ms de física garantem que dois acertos não sejam iguais.
- **`bVelChange = true` no impulso**: a reação não depende da massa dos corpos do Physics Asset, que muda quando alguém ajusta o asset.
- **A morte para a física parcial antes do ragdoll**, e não depois: dois sistemas mexendo na simulação dos mesmos ossos no mesmo frame produzem um corpo que "salta".
- **O notify de passo não emite ruído para a IA.** Os passos dos vigias e da Presença são informação para a jogadora; ruído para a IA vem de ações da jogadora (Cap. 36).
- **Dados de reação num asset** (`UVGHitReactionData`): um vigia novo, ou um corpo diferente, é um asset novo, não código.

---

## Projeto Vigília — corpos que contam

### Os vigias (setor 2)

- `ABP_Vigia` (pai: `UVGAnimInstance`): máquina de locomoção (chão/ar/aterrissa), `BS_Vigia_Locomocao` (2D: `Speed` × `Direction`), `AO_Vigia_Mira`, slot `UpperBody` para disparo e recarga, slot `FullBody` para reações, IK de pés nas escadas da subestação.
- `DA_Reacao_Vigia` (`UVGHitReactionData`) com os quatro montages por direção e o de *stagger*; `UVGPhysicalReactionComponent` com `spine_01`, pico 0,6, 0,35 s.
- A pose de cobertura baixa e alta (Cap. 41) como estados da máquina, lidos de uma tag de status de cobertura, se o seu Capítulo 41 a concede (ou de um valor do controller).
- Passos por `UVGAnimNotify_Footstep` nas animações de andar e correr.

### A Presença

- `ABP_Presenca` (pai: `UVGAnimInstance`, `bTrackCeiling = true`, `CeilingClearance = 220`): locomoção com cadência irregular, *look-at* na cabeça, a dobra por `LowCeilingAlpha`.
- Montages: `AM_Presenca_Telegrafia` (1,2 s, corpo inteiro, sempre o mesmo começo), `AM_Presenca_Ataque`, `AM_Presenca_Recuo` (*root motion*, o recuo diante da luz).
- 🔁 O `UVGPresenceReactionComponent` (Cap. 37) toca `AM_Presenca_Recuo` ao receber dano de luz, **além** de escrever o Blackboard. A árvore continua decidindo o recuo pela navegação; o montage é a apresentação do início.
- 🔁 O `OnTelegraph(bool)` do Blueprint do corpo (Cap. 37) toca `AM_Presenca_Telegrafia`. A task continua dona do tempo e do dano (`ApplyDamage` no fim, Cap. 37); o montage **acompanha**. O exercício confere que os dois duram o mesmo.
- `VisibilityBasedAnimTickOption = AlwaysTickPoseAndRefreshBones`: a Presença anima mesmo fora da tela, para os passos dela continuarem soando (seção 53.2).
- A silhueta do susto: uma *Pose Asset* (ou um frame único) do mesmo esqueleto, no *spawnable* de `BP_Cena_Susto` (Cap. 49).

### Helena: os braços

- `SK_Bracos_Helena` presa à câmera, `OnlyOwnerSee`, **sem sombra**; `ABP_Bracos` com *idle*, andar e correr (sutis: o *head bob* do Capítulo 18 já move a câmera), a mão esquerda segurando `SM_Lanterna` e a direita alcançando a empunhadura da arma por *two-bone IK*.
- 🔁 O `UVGWeaponComponent` (Caps. 26 e 29) continua dono da posição da arma (`ApplyWeaponOffset`); a arma passa a ser presa ao mesmo pai que os braços, e a mão a segue por IK.
- Montages de braços: sacar, guardar e recarregar (com notify `PenteEncaixado`: a recarga só conta ao chegar nele, e correr ou acender a lanterna a cancela).
- Gestos de vulnerabilidade: tremor aditivo na mão da lanterna proporcional ao nível de ameaça (`UVGThreatSubsystem`, lido no `ABP_Bracos`).

---

## Decisões arquiteturais

1. **O ABP lê o estado do jogo e não é dono de nenhum**; a animação devolve informação só por notifies, e nenhuma regra crítica depende de um notify sem caminho alternativo.
2. **Locomoção *in place*** (a navegação manda); ***root motion*** só em montages em que a posição é autoral (o recuo da Presença).
3. **Estados qualitativos na máquina; variações contínuas em blend spaces.**
4. **Reação dos vigias = montage por direção + física parcial**; ragdoll na morte; a Presença sem física no corpo.
5. **A Presença anima sempre**, mesmo fora da tela, porque os passos dela são informação.
6. **Primeira pessoa só com braços**, lanterna na mão esquerda, armas de uma mão, braços sem sombra, feixe na câmera.
7. **Motion Matching e Control Rig fora do escopo** da Vigília; nós de IK do anim graph bastam.

---

## Armadilhas

- **Gameplay dentro do Animation Blueprint** (o ABP decidindo se o personagem pode atacar).
- **Esperar o fim de um montage** sem tratar a interrupção.
- **Montage e regra com durações diferentes** (a telegrafia de 1,2 s com uma animação de 0,8 s).
- **Pés patinando** por eixos de blend space que não batem com a velocidade real.
- **Não animar fora da tela** um personagem cujos notifies são informação.
- **Física parcial colidindo com a própria cápsula.**
- **Dois sistemas mexendo na simulação dos mesmos ossos** (a reação parcial e o ragdoll no mesmo frame).
- **Braços que projetam sombra** da lanterna presa à câmera.
- **A lanterna no osso da mão** como fonte de luz e de mira: o feixe treme com cada animação, e o cone da sobrecarga deixa de apontar para onde a jogadora mira.
- **Leituras do jogo espalhadas pelo anim graph** (*casts* e chamadas em nós que podem rodar fora do *game thread*).

---

## Exercício

**Parte 1 — a base e as regras (1,5 h).** Implemente `VGAnimRules`, o teste e `UVGAnimInstance`. Crie `ABP_Vigia` com a máquina de locomoção, o blend space 2D e o aim offset. Ponha um vigia patrulhando (Cap. 37) e confira com o *Animation Insights*/a depuração do ABP (⚠️ ferramentas por versão) que `Speed` e `Direction` fazem sentido.

**Parte 2 — reações (2 h).** Implemente `UVGHitReactionData`, `UVGPhysicalReactionComponent` e o 🔁 do `AVGEnemyCharacter`. No Galpão de Testes (Projeto 2), atire num vigia de frente, de lado e de costas: a leitura (montage) deve ser clara, e dois tiros iguais não devem produzir o mesmo movimento. Mate um vigia no meio de um tranco e confira que o ragdoll assume sem salto.

**Parte 3 — a Presença (2 h).** Crie `ABP_Presenca` com *look-at* e a dobra por teto. Monte um vão de 200 cm em `L_Lab` e veja-a passar. Grave a telegrafia e meça: o montage e a task do Capítulo 37 duram o mesmo? Com `VisibilityBasedAnimTickOption` no padrão e depois em "sempre", feche os olhos (vire a câmera) e ouça os passos dela: em qual dos dois eles somem?

**Parte 4 — os braços (1,5 h).** Monte `SK_Bracos_Helena` com a lanterna na esquerda e a pistola de sinalização na direita, por IK. Desligue a sombra dos braços e compare com ela ligada, encostada numa parede iluminada pela lanterna.

---

## Desafio — o feixe que respira

O feixe da lanterna está preso à câmera (Cap. 51) e, por isso, é preciso e um pouco "morto". Faça o feixe ganhar vida **sem** perder precisão:

1. Faça o componente de luz seguir a rotação da câmera com um pequeno atraso (uma interpolação de alguns graus por segundo) e uma oscilação mínima ligada ao balanço da mão esquerda.
2. A percepção (`Status.Light.Flashlight`) não muda; mas o cone da sobrecarga (Cap. 51) deve usar a direção **da câmera** ou **do feixe**? Decida: qual das duas a jogadora sente como "para onde eu apontei"? Teste com alguém e registre no `DEVLOG.md`.
3. Garanta que a opção `vg.Camera.Motion` (Cap. 18) também reduza esse atraso e essa oscilação. Quem sente enjoo com o balanço da câmera provavelmente sente com o do feixe.

---

## Uso de IA

1. **Para desenhar a máquina de estados:**
   > "Estou montando o Animation Blueprint de um soldado de IA em Unreal Engine 5: locomoção em 8 direções, mira independente do movimento, cobertura baixa e alta, recarga, reações a tiros por direção e morte com ragdoll. Proponha a divisão entre máquina de estados, blend spaces, aim offset, slots e montages, e justifique cada escolha pela regra 'estados para o qualitativo, blend spaces para o contínuo'. Diga o que NÃO deveria estar no Animation Blueprint."

2. **Para revisar código de animação:**
   > "Revise esta classe C++ derivada de UAnimInstance (abaixo). Procure: leituras do jogo que poderiam rodar fora do game thread; estado de jogo sendo decidido pela animação; chamadas caras por frame que poderiam ser mais raras; e uso de APIs depreciadas no UE5. [código]"

3. **Para caracterizar a criatura:**
   > "Uma criatura de terror de 2,1 m, invencível, aparece pouco e precisa parecer 'não humana' pelo movimento. Proponha dez características de animação (cadência, poses, transições, reações à luz, como passa por portas) que um animador poderia fazer com um orçamento pequeno, em ordem de impacto por custo."

**Cuidado específico:** a IA mistura APIs de animação de versões diferentes com facilidade: assinaturas de `UAnimNotify::Notify`, funções de cálculo de direção que mudaram de lugar, nós de anim graph que existem só com certos plugins. E ela não **vê** animação: sugestões de "como deve parecer" são hipóteses que só um teste no editor, com o personagem andando na sua cena, confirma.

---

## Checklist

- [ ] Sei o que são esqueleto, skeletal mesh, physics asset, sequence, blend space, aim offset e montage.
- [ ] Sei por que o ABP lê e não decide, e onde coletar os dados do jogo.
- [ ] Sei montar uma máquina de locomoção com blend space e aim offset sem pés patinando.
- [ ] Sei usar montages e notifies sem deixar regras críticas reféns deles.
- [ ] Sei onde IK compensa (pés, mão na arma, cabeça).
- [ ] Sei a diferença entre ragdoll, física parcial e animação física, e a usei nos vigias.
- [ ] A Presença se move como algo não humano e anima mesmo fora da tela.
- [ ] Helena tem braços, com a lanterna na mão esquerda, sem sombra, e o feixe preso à câmera.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation): **Skeletal Mesh Animation System**, **Animation Blueprints**, **State Machines**, **Blend Spaces**, **Animation Montage**, **Animation Notifies**, **Physical Animation**, **IK Rig/Retargeting**, **Control Rig** e **Motion Matching**.
- **GDC Vault** (gdcvault.com): a palestra de Simon Clavet (Ubisoft) sobre *motion matching* em *For Honor*, da GDC 2016 (confira o título lá), e palestras sobre animação procedural e animação física em jogos.
- **Jason Gregory, *Game Engine Architecture*** — o capítulo sobre sistemas de animação (esqueletos, *skinning*, *blending*, pipeline de animação).

---

➡️ **Próximo:** [Capítulo 54 — VFX](cap-54-vfx.md)
