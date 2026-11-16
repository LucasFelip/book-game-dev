# Parte VII — Estado

## 1. Capítulos concluídos

- **Cap. 50 — Level Design** (`cap-50-level-design.md`).
- **Cap. 51 — Lighting** (`cap-51-lighting.md`).
- **Cap. 52 — Audio** (`cap-52-audio.md`).
- **Cap. 53 — Animation** (`cap-53-animation.md`).
- **Cap. 54 — VFX** (`cap-54-vfx.md`).
- **Cap. 55 — UI/UX** (`cap-55-ui-ux.md`). Termina com o "Estado do Livro (fim da Parte VII)" e o ➡️ para `../parte-08/cap-56-save-systems.md`.

## 2. Classes, tags, CVars, cheats e testes

### Cap. 50
- **Classes:** `VGPuzzleRules` (namespace, `Evaluate` → `EStep` Ignore/Advance/Complete/Fail), `AVGSequencePuzzle` (World/; `Sequence` em ordem, `PuzzleTag`, `PoweredSector`, `FailResetDelay`, `ForceSolve(bool bAnnounce)`, `OnSolved`, `OnPuzzleFeedback(EVGPuzzleFeedback)`), `EVGPuzzleFeedback` (Advanced/Failed/Reset/Solved).
- 🔁 `AVGBreakerSwitch::SetLocked(bool)` (+ `bLocked`, checado em `CanInteract`); 🔁 `AVGSector::SetPowered(bool)` (lógica do handler do disjuntor extraída; disjuntor principal opcional).
- **Tags nativas:** `Event.Puzzle.Solved`, `Event.Puzzle.Failed`. **Conteúdo:** `Puzzle.S1.Breakers`, `Puzzle.S2.Disconnectors`.
- **Cheat:** `VGSolvePuzzle <PuzzleTag>`.
- **Teste:** `Vigilia.World.Puzzle.Sequence` (`VGPuzzleRulesTest.cpp`).
- **Assets/docs:** kit `SM_BK_*` e materiais `MI_BK_*`; `docs/design/metricas.md`; `docs/design/niveis/S1-casa-de-forca.md` (+ S2, S3); níveis `L_Subestacao`, `L_Turbinas` em blockout.

### Cap. 51
- **Classes:** `UVGFlashlightComponent` (Player/; **deriva de `USpotLightComponent`**; `Toggle()`, `RequestOvercharge()`, `GetState()`, `GetOverchargeReadiness()`, `OnStateChanged`; dona da própria intensidade; bateria = `UVGBatteryComponent` do dono), `EVGFlashlightState` (UENUM: Off/On/Flickering/Overcharge/Depleted), `EVGFlashlightInput`, `FVGFlashlightContext`, `VGFlashlightRules` (`Next`, `IsBeamVisible`), `VGFlickerRules::SampleScale` (🔁 extraída do `UVGFlickerComponent`), `AVGLightFixture` (World/; `LitWhen` sobre fatos, `ProtectedZone`, sinais do Diretor com `SignalProfile`/`SignalRadius`/`SignalSeconds`, `IdlePattern`; contém um `UVGFlickerComponent`).
- 🔁 `AVGCharacter`: componente `Flashlight` preso à câmera; `FlashlightAction` (`IA_Lanterna`), `OverchargeAction` (`IA_SobrecargaLanterna`, trigger Hold 0,35 s), `OnOverchargeCharging(bool)` (BlueprintImplementableEvent). 🔁 `AVGSector` deixa de ativar zonas seguras (quem ativa é a luminária dona).
- **Tag nativa:** `Status.Light.Overcharge`.
- **CVar:** `vg.Debug.Flashlight`.
- **Teste:** `Vigilia.Player.Flashlight.Transitions` (`VGFlashlightRulesTest.cpp`, inclui `VGFlickerRules`).
- **Assets:** `BP_Luminaria_Emergencia`, `BP_Luminaria_Servico`, `BP_Destaque`.

### Cap. 52
- **Módulo:** `AudioExtensions` no `Build.cs` (interface de parâmetros do `UAudioComponent`; ⚠️ conferir).
- **Classes (Source/Vigilia/Core/):** `VGAudioRules` (`MusicTension(Phase, Tension)`, `RadioInterference(Threat, Phase)`, `FootstepVolume(FinalLoudness)`), `UVGAudioSettings` (`UDeveloperSettings`, "Vigilia Audio": `ReadingMix`, `CinematicMix`, `MenuMix`, `DeadMix`, `SilenceMix`, `TensionScore`), `UVGAudioMixSubsystem` (`UWorldSubsystem`; mix derivado do modo de input no topo; `PushSilence(FName)`/`PopSilence(int32)` com handle; timer de 4 Hz alimenta `Tensao` da trilha e `Interferencia` do rádio; liga-se ao controller de forma preguiçosa).
- 🔁 `UVGSpeakerData::VoiceChain` (USoundBase); 🔁 `UVGDialogueSubsystem::StartLine` (CreateSound2D + `SetObjectParameter("Voz")` quando há cadeia) e `SetVoiceFloatParameter(FName, float)`; 🔁 `UVGPhysicalMaterial::FootstepSound`; 🔁 `FVGFootstepSignature` com `const UPhysicalMaterial*` (a sugestão do Cap. 36); 🔁 `AVGCharacter::HandleFootstep` toca o som e reporta o ruído com a mesma `FinalLoudness`.
- **Teste:** `Vigilia.Audio.Rules` (`VGAudioRulesTest.cpp`; inclui monotonicidade som × ruído).
- **Assets:** Sound Classes `SC_Master/Mundo/Ambiente/Jogadora/Presenca/Voz/Voz_Radio/Trilha/UI`; mixes `SMix_Leitura/Cinematica/Menu/Morte/Silencio`; MetaSounds `MS_Passo_*`, `MS_Usina_Respira` (entrada `Intensidade`), `MS_Radio_Voz` (entradas `Voz`, `Interferencia`), `MS_Trilha_Tensao` (entrada `Tensao`), `MS_Presenca_Respira`; atenuações `ATT_Passos`, `ATT_Presenca`, `ATT_Ambiente_Pontual`.

### Cap. 53
- **Classes:** `VGAnimRules` (AI/; `LocomotionDirection`, `FlinchWeight`), `UVGAnimInstance` (AI/; base dos ABPs de vigias e Presença; `Speed`, `Direction`, `bIsFalling`, `bIsCrouching`, `AimPitch/AimYaw`, `LookAtLocation/LookAtAlpha` do foco do AIController, `LowCeilingAlpha` com `bTrackCeiling`/`CeilingClearance`), `UVGAnimNotify_Footstep` (AI/; som do `FootstepSound` do material, sem ruído para a IA), `UVGHitReactionData` (Combat/; montages por `EVGHitDirection` + `Stagger`, `Pick`), `UVGPhysicalReactionComponent` (Combat/; `Flinch(Bone, Impulse)`, `Stop()`; cria um `UPhysicalAnimationComponent`).
- 🔁 `AVGEnemyCharacter`: `HitReactions`, `PhysicalReaction`, `FlinchImpulse`, `bPhysicalHitReactions` (falso na Presença); montage + tranco antes de `OnHitReaction`; `PhysicalReaction->Stop()` antes do ragdoll.
- 🔁 `UVGPresenceReactionComponent` toca `AM_Presenca_Recuo`; `OnTelegraph` toca `AM_Presenca_Telegrafia` (a task do Cap. 37 continua dona do tempo e do dano).
- **Teste:** `Vigilia.Animation.Rules` (`VGAnimRulesTest.cpp`).
- **Assets:** `ABP_Vigia`, `BS_Vigia_Locomocao`, `AO_Vigia_Mira`, `DA_Reacao_Vigia`, `ABP_Presenca`, `AM_Presenca_Telegrafia/Ataque/Recuo`, `SK_Bracos_Helena`, `ABP_Bracos`, `SM_Lanterna`.

### Cap. 54
- **Classes:** `VGImpactRules::ShouldSpawnVisuals` (Combat/), `UVGDirectorSignalComponent` (World/; `Radius`, `OnSignal`; ouve `Event.Director.BuildUp`).
- 🔁 `UVGImpactEffects::PlayAt` (pool nativo `ENCPoolMethod::AutoRelease`, `MaxVisualDistance`, orçamento por frame; o som fica fora do orçamento); 🔁 `UVGWeaponData::MuzzleFlash` + `SpawnSystemAttached` no disparo; 🔁 `AVGFlareProjectile::BurnFx` (`NS_Sinalizador`, parâmetro `Restante`, fonte única da luz e do efeito); 🔁 `AVGLightFixture` passa a usar `UVGDirectorSignalComponent` (sai `SignalRadius` e a escuta do barramento).
- **CVar:** `vg.Fx.ImpactBudget` (int, 8, `ECVF_Scalability`).
- **Teste:** `Vigilia.Combat.ImpactBudget` (`VGImpactRulesTest.cpp`).
- **Assets:** `NS_PoeiraFeixe` (parâmetros `FeixeOrigem`, `FeixeDirecao`, `FeixeCos`), `NS_Sobrecarga`, `NS_Presenca_Queimada`, `NS_Sinalizador`, `NS_Gota`, `NS_Poeira_Teto`, `NS_Turbina_Faiscas`, `NS_MuzzleFlash`, `NS_Rastro`; `BP_PoeiraDoTeto`; `M_PP_Contorno`; `MI_Decal_MaoPoeira`.

### Cap. 55
- **Módulos:** `UMG`, `Slate`, `SlateCore` no `Build.cs`.
- **Classes:** `VGUIRules` (UI/; `FVGUILayers` {bGame, bReading, bMenu, bDeath, bOverlay}, `LayersFor(EVGInputMode)`), `UVGHUDLayout` (UI/; `BindWidget` GameLayer/ReadingLayer/MenuLayer/DeathLayer/OverlayLayer; inscreve-se em `OnInputModeChanged`), `UVGSubtitleWidget` (UI/; base do `WBP_Legenda`: SpeakerText, LineText, RadioIcon, Background), `UVGGameUserSettings` (Core/; subclasse de `UGameUserSettings`, registrada em `DefaultEngine.ini`; `Get()`, `ApplyAccessibility()`, `ApplyAudio()`, `OnAccessibilityApplied`; opções `bSubtitlesEnabled`, `SubtitleScale`, `SubtitleBackgroundOpacity`, `bShowSpeakerNames`, `CameraMotion`, `FieldOfView`, `bFlickerEnabled`, `BrightnessBias`, `MusicVolume`, `VoiceVolume`, `EffectsVolume`, `bFirstRunDone`).
- 🔁 `AVGPlayerController`: `HUDLayoutClass`, `HUDLayout`, `OpenPauseMenu()`, `ClosePauseMenu()`; aplica acessibilidade e áudio no `BeginPlay` local. Input: `IA_Pausa`.
- **Teste:** `Vigilia.UI.Layers` (`VGUIRulesTest.cpp`).
- **Assets:** `WBP_HUD`, `WBP_Legenda`, `WBP_RespostasRadio`, `WBP_Prompt`, `WBP_Municao`, `WBP_AvisoObjetivo`, `WBP_Mira`, `WBP_Documento`, `WBP_Menu` (abas Diário e Arquivo), `WBP_Opcoes`, `WBP_PrimeiraVez`, `WBP_Morte`, `M_PP_Dano`, `SMix_Opcoes`.

## 3. Decisões firmadas

- Sem marcadores de objetivo no mundo: o diário diz o quê, o espaço diz onde.
- Métricas da Vigília (v1) derivadas dos sistemas: cápsulas Humano 34/176 e Presença 28/210; vão ≥ 220 cm para a Presença; alcance de interação 220; alcance útil da lanterna ~12–15 m; visão da Presença 30 m; corredor principal 2,0–2,4 m; corredor de serviço 1,2–1,4 m.
- A curva do corredor: linha de visão ≤ 8 m antes do ponto de virada, ~18 m depois; silhueta a ~16 m (na borda da luz da lanterna).
- Gate de conhecimento do puzzle continua mole (tentativa e erro possível).
- Nenhum espaço de caça sem rota de fuga; perseguição com laço, porta que fecha e destino iluminado.
- Um nível por setor, sem World Partition (`L_Patio`, `L_CasaDeForca`, `L_Subestacao`, `L_Turbinas`, `L_Final`).
- Setor 2: rotas de Sônia (galeria de cabos) e de Moraes (casa de comando) convergem antes do pátio dos vigias; Presença travada fora do pátio enquanto houver vigias vivos; seccionadoras reutilizam `AVGSequencePuzzle` (4 alavancas).
- Setor 3: galeria superior (vista da janela do setor 1) → passarelas em laço → poço da turbina 3 (revelação) → comando manual (única zona segura); perseguição na volta do poço; atalho de escada que abre de baixo.
- Projeto da Parte VII intitulado "Projeto Vigília — …" (a Parte VII não tem número de projeto próprio).
- **Linguagem de luz** (Cap. 51): segurança = âmbar estável que ilumina o chão (sempre com zona); atenção = destaque pontual que não ilumina o chão; energia = luminárias de serviço frias (por fatos); perigo = falha/cascata (sempre a Presença); a lanterna pisca só por bateria.
- **Sobrecarga da lanterna** (Cap. 51; para o documento de combate v1.0 do Cap. 76): segurar `IA_SobrecargaLanterna` 0,35 s com a lanterna acesa; custo 25 de carga (bateria 100); pulso 0,3 s; cone 8 m, meio-ângulo 25°, com linha de visão; `UVGDamageType_Light` magnitude 40 (Presença ~2 s de atordoamento; vigias imunes); cooldown 6 s; feixe a 30% por 1 s depois; ruído 0,6 / 15 m (tag `Overcharge`); `Status.Light.Overcharge` durante o pulso. Não funciona com a lanterna apagada; o interruptor não interrompe o pulso.
- Bateria continua na jogadora; dreno 0,8/s acesa.
- Luzes do mundo leem **fatos** (não eventos); a luminária é dona da zona que protege ("só é seguro onde há luz" por construção); o Diretor só faz falhar luminárias sem zona.
- A lanterna não altera a NavMesh; age por percepção (tag) e dano (sobrecarga).
- Sombras: a lanterna sempre; luzes do mundo só as que compõem (meta no setor 1: lanterna + 2).
- Exposição com faixa estreita; sem preto absoluto no caminho crítico.
- **Áudio** (Cap. 52): mixagem por *Sound Mixes* empilhados (Audio Modulation só se necessário); mix derivado do modo de input no topo (Reading: mundo −6 dB + passa-baixa, Presença intacta; Cinematic; UI; Dead); silêncio pedido por cena com handle (ambiente a zero em 0,2 s, volta em 1,5 s; nunca zero digital).
- A Presença nunca é abafada pela mixagem nem mente sobre a posição; atenuação ~15 m, oclusão ligada só nela; telegrafia sonora e espacial.
- Paridade som × ruído: mesmo handler, mesma `FinalLoudness`.
- Filtro de rádio = cadeia do falante (`MS_Radio_Voz`: 300 Hz–3,4 kHz, saturação, squelch, interferência). Interferência vem do `UVGThreatSubsystem` (Calm 0,05 / Uneasy 0,35 / Hunting 0,7) + 0,15 em BuildUp.
- Trilha quase ambiente guiada pela tensão do Diretor; não confirma o perigo de forma confiável; no máximo um *stinger* por setor.
- A usina "respira" com `MS_Usina_Respira` (substitui o `AVGAlarm` filho do Interlúdio).
- **Animação** (Cap. 53): o ABP lê e não é dono de estado; locomoção *in place*, *root motion* só em montages autorais (recuo da Presença); reação dos vigias = montage por direção + física parcial (spine_01, pico 0,6, 0,35 s); a Presença sem física no corpo e com `VisibilityBasedAnimTickOption` = sempre animar (os passos dela são informação); primeira pessoa só com braços (lanterna na mão esquerda, armas de uma mão, braços sem sombra, feixe preso à câmera); Motion Matching e Control Rig fora do escopo.
- **VFX** (Cap. 54): todo efeito tem função escrita (confirmação, estado, atmosfera); gameplay escreve parâmetros de usuário, interpolação no Niagara; poeira do feixe por teste de cone em partículas *unlit*; contorno de interação fino e quente só no objeto focado (confirmação, não descoberta); a vinheta de dano é pós-processamento cujo dono é a UI (Cap. 55); a Presença atingida pela luz "queima" (`NS_Presenca_Queimada`) como confirmação.
- **UI** (Cap. 55): preferência diegético > meta > espacial > não diegético (acessibilidade acima de imersão); um layout raiz (`WBP_HUD`) com 5 camadas (Game, Reading, Menu, Death, Overlay) derivadas só do modo no topo; widgets não empilham modos, pedem ao dono (controller dono de `UI`; leitor dono de `Reading`; morte dona de `Dead`); sem lista de objetivos (aviso de 3 s ao mudar de etapa; diário no menu), sem números de vida (vinheta + respiração), mira só com arma, *hit marker* só no trecho dos vigias; bateria diegética (LED na lanterna; fixo em vermelho sem flicker); legendas ligadas por padrão e oferecidas na primeira execução com a calibração de brilho; "reduzir luzes piscando" vale para o jogo inteiro (o susto vira escurecimento em sequência); CommonUI não adotado (reavaliar se o alvo for console).
- Pastas: classes de animação em `AI/` (base do ABP, notify) e `Combat/` (reações); áudio e configurações em `Core/`; UI em `UI/`. Nenhuma pasta nova além da lista do guia.

## 4. Pendências para capítulos seguintes

- **Cap. 56 (Save):** salvar as opções é do `UGameUserSettings` (já em `.ini`, fora do save de jogo); o save de jogo herda: fatos (luzes e zonas se restauram sozinhas), estado do puzzle (`AVGSequencePuzzle::ForceSolve(false)`), carga da bateria e estado da lanterna (`UVGFlashlightComponent`; restaurar como `Off` é aceitável).
- **Cap. 57 (Persistence):** documentos "levados" (Cap. 48) e o puzzle resolvido no setor carregado.
- **Cap. 58–59 (Performance/Profiling):** os números registrados no DEVLOG pelos Caps. 51 (luz no corredor do susto), 53 (animação; a Presença sempre animando) e 54 (efeitos no corredor e no tiroteio do setor 2, `vg.Fx.ImpactBudget`); invalidação de UI (Cap. 55).
- **Cap. 62 (Packaging):** decidir a plataforma-alvo; se for console, reavaliar CommonUI (Cap. 55).
- **Parte XI (Caps. 79/81):** documentos, falas e arte dos setores 2 e 3; os números da perseguição (desafio do Cap. 50); o caderno de Helena (desafios dos Caps. 48 e 55).

## 5. Ajustes sugeridos em outras partes

- **Cap. 19 (`AVGBreakerSwitch`)**: registrar no README a adição de `SetLocked` (Cap. 50).
- **Caps. 23–24 (`AVGSector`)**: o README pode citar `SetPowered(bool)` como API pública do setor a partir do Cap. 50.
- **Cap. 76**: a tabela de setores pode referenciar as plantas de blockout do Cap. 50 (S2-01…S2-06, S3-01…S3-04). O documento de combate v1.0 deve usar os números da sobrecarga registrados acima.
- **Cap. 4**: o esboço de `UVGFlashlightComponent::TryTransition` agora tem implementação real no Cap. 51 (o enum ganhou `UENUM` e mora em `Player/VGFlashlightRules.h`).
- **Cap. 9**: a amostragem de padrão do `UVGFlickerComponent` passa a chamar `VGFlickerRules::SampleScale` (Cap. 51).
- **Caps. 23–24**: o `AVGSector` não ativa mais zonas seguras a partir do Cap. 51; o README deve refletir isso.
- **Cap. 42**: o ator de ambiência por setor (Blueprint) perde a parte de "fazer uma luz falhar"; isso passa às `AVGLightFixture` (Cap. 51). Fica com o som.
- **README**: `UVGFlashlightComponent` é um `USpotLightComponent`, não um `UActorComponent`.
- **Cap. 44**: o comentário "o filtro de áudio vem no Cap. 52" em `UVGSpeakerData` fica resolvido por `VoiceChain`; o `StartLine` mostrado no Cap. 44 ganha o ramo da cadeia (Cap. 52).
- **Cap. 36**: a "simplificação" de passar o material físico no `FVGFootstepSignature` vira obrigatória a partir do Cap. 52.
- **Cap. 49**: `BP_Cena_Susto` passa a pedir `PushSilence`/`PopSilence` (no `Finish` único).
- **Interlúdio I**: o `AVGAlarm` filho que fazia a usina "respirar" é substituído por `MS_Usina_Respira` (Cap. 52).
- **Cap. 30**: `AVGEnemyCharacter` ganha reação em C++ (montage + física parcial) antes do `OnHitReaction` (Cap. 53).
- **Caps. 26/29**: a arma passa a ser presa ao mesmo pai dos braços; `ApplyWeaponOffset` continua dono da posição, a mão segue por IK (Cap. 53).
- **Cap. 37**: o `UVGPresenceReactionComponent` passa a tocar o montage de recuo (Cap. 53) e a disparar `NS_Presenca_Queimada` no ponto atingido (Cap. 54); `OnTelegraph` toca o montage de telegrafia (Cap. 53).
- **Cap. 27**: `UVGImpactEffects::PlayAt` passa a usar pool nativo e orçamento (Cap. 54).
- **Cap. 28**: `AVGFlareProjectile` ganha `BurnFx` e o parâmetro `Restante` (Cap. 54).
- **Cap. 19**: o contorno de interação prometido ("material de pós-processamento, Cap. 54") é `M_PP_Contorno`; exige *Custom Depth-Stencil Pass* habilitado.
- **Cap. 32**: a "escala com efeitos à distância" foi tratada como estudo de caso no Cap. 54.
- **Caps. 19, 20, 24, 31, 44, 45, 48**: os widgets provisórios foram migrados ou removidos no Cap. 55 (tabela "Do provisório ao definitivo"); o HUD de objetivos do Cap. 31 e o texto de munição do Cap. 20 saem da tela da jogadora.
- **Cap. 16**: `AVGPlayerController` ganha `OpenPauseMenu`/`ClosePauseMenu`, `HUDLayoutClass`/`HUDLayout` e `IA_Pausa` em `IMC_Exploracao`/`IMC_Leitura`/`IMC_Cinematica` (abre) e `IMC_UI` (fecha) (Cap. 55).
- **Cap. 18**: `AVGPlayerCameraManager` lê `FieldOfView` das opções; um modificador de câmera aplica `BrightnessBias` via `ModifyPostProcess` (Cap. 55).
- **Cap. 52 ↔ 55**: `UVGAudioSettings` ganha `OptionsMix`, `MusicClass`, `VoiceClass`, `EffectsClass` (Cap. 55).
- **Cap. 76**: o *must* "legendas e opções de acessibilidade" está cumprido para o setor 1 (Cap. 55).
- **Guia de produção**: considerar registrar `Status.Light.Overcharge`, `IA_SobrecargaLanterna` e `UVGFlashlightComponent` na seção de API planejada, para a Parte XI citar sem grep.
