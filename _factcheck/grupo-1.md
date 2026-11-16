# Fact-check — grupo 1 (00-introducao, parte-01, parte-02)

Vereditos: OK | CORRIGIDO | REBAIXADO | REMOVIDO
"consagrado" = fato amplamente estabelecido, não gastei busca.

| arquivo:linha | afirmação (curta) | veredito | fonte (URL) | mudança feita |
|---|---|---|---|---|
| 00-introducao.md:199 | Estúdios citados (The Chinese Room em A Machine for Pigs, Konami, EA etc.) | OK | consagrado | — |
| 00-introducao.md:287 | Prefixos de assets "por exemplo" o UE5 Style Guide de Allar | OK (ressalva: NS_/IA_/IMC_/MS_ não aparecem no guia de Allar, mas o texto diz "por exemplo"; o conteúdo UE5 fica no branch v2) | https://github.com/Allar/ue5-style-guide | — |
| 00-introducao.md:496 | VS 2022 com a carga "Game development with C++" | OK (VS 2022 ainda é a toolchain recomendada na UE 5.7) | https://forums.unrealengine.com/t/unreal-engine-5-7-and-visual-studio-2026/2674488 | — |
| 00-introducao.md:547 | GPP gratuito em gameprogrammingpatterns.com | OK | consagrado | — |
| 00-introducao.md:548 | Jason Gregory trabalhou na Naughty Dog | OK | https://www.perlego.com/book/4364482/game-engine-architecture-pdf | — |
| 00-introducao.md:549 | Schell, *The Art of Game Design: A Book of Lenses* | OK | consagrado | — |
| cap-01:27 | Alan Wake original no Xbox 360 rodava a 30 fps | OK | https://imagequalitymatters.blogspot.com/2010/05/tech-analysis-alan-wake.html | — |
| cap-01:87 | PES 2011 no PlayStation 2 | OK | consagrado | — |
| cap-01:428 | [FATO PÚBLICO] Alan Wake (Remedy, 2010): Taken, lanterna/bateria, sinalizadores, refúgios iluminados/checkpoints | OK | consagrado (observável) | — |
| cap-01:474 | [INFERÊNCIA] implementação da luz: declarada como hipótese, sem atribuir à Remedy | OK | — | — |
| cap-01:570-575 | Outlast (câmera/baterias), Amnesia (sanidade), Control (Oldest House), COD (hit marker), GTA SA (wanted level) | OK | consagrado | — |
| cap-01:630 | GPP, introdução "Architecture, Performance, and Games" | OK | https://gameprogrammingpatterns.com/architecture-performance-and-games.html | — |
| cap-01:632 | GEA, Cap. 1 Introdução | OK | https://bookcurl.com/products/game-engine-architecture-third-edition-9781138035454 | — |
| cap-02:23 | Intenção do padrão Game Loop segundo Nystrom | OK | https://gameprogrammingpatterns.com/game-loop.html | — |
| cap-02:123 / :659 | *Fix Your Timestep!*, Glenn Fiedler, Gaffer On Games | OK | https://gafferongames.com/post/fix_your_timestep/ | — |
| cap-02:212 | Código da Unreal acessível com licença + conta Epic vinculada ao GitHub | OK | consagrado | — |
| cap-02:660 | Doc oficial "Actor Ticking" | OK | consagrado | — |
| cap-02:661 | GEA: capítulo sobre game loop e tempo real | OK (Cap. 8, "The Game Loop and Real-Time Simulation") | https://bookcurl.com/products/game-engine-architecture-third-edition-9781138035454 | — |
| cap-03:22 | Remedy fez Max Payne 1 e 2 e Quantum Break; MP3 é da Rockstar | OK | consagrado | — |
| cap-03:153 | Modificador *Scale By Delta Time* no Enhanced Input | OK | consagrado (API) | — |
| cap-03:285-289 | Chaos: substepping e *Tick Physics Async* (rotulado como variável entre versões) | OK | consagrado | — |
| cap-03:320 | [INFERÊNCIA] replays de PES/FIFA; sistema de replay da Unreal grava replicação | OK (inferência bem marcada) | — | — |
| cap-03:382 | [FATO PÚBLICO] Max Payne (2001): medidor de Bullet Time recarrega com abates; shootdodge | OK | https://support.rockstargames.com/articles/6mgfz9AeJqbn3vsyCiMSxH/what-is-bullet-time-and-how-can-i-use-it-to-my-advantage ; https://maxpayne.fandom.com/wiki/Shootdodge?oldid=4015 | — |
| cap-03:384 | [FATO PÚBLICO] Quantum Break (2016): poderes, stutters, episódios live-action que mudam com escolhas | OK | https://www.gamespot.com/articles/quantum-break-live-action-episodes-can-be-skipped-/1100-6435420/ ; https://stevivor.com/features/interviews/quantum-break-tv-episodes-junctions-make-variation-game-single-ending/ | — |
| cap-03:421 | [INFERÊNCIA] tempo em Max Payne/QB: sem afirmar nada sobre os motores da Remedy | OK | — | — |
| cap-03:477 | [FATO PÚBLICO] COD prioriza 60 fps nos consoles desde PS3/360, com resolução menor | OK (COD4 a 1024x600 nos dois consoles) | https://www.engadget.com/2007/11/22/call-of-duty-4-not-hd-only-600p-claim-pixel-counters/ | — |
| cap-03:887 | Fiedler, "Integration Basics" | OK | https://gafferongames.com/post/integration_basics/ | — |
| cap-04:96 / :889 | Single Writer Principle, Martin Thompson, blog Mechanical Sympathy, LMAX | OK (post de 22/09/2011) | https://mechanical-sympathy.blogspot.com/2011/09/single-writer-principle.html | — |
| cap-04:341 | Padrão *Event Queue* em GPP | OK | https://gameprogrammingpatterns.com/event-queue.html | — |
| cap-04:460 | [FATO PÚBLICO] GTA SA (2004): até 6 estrelas, escalada até o Exército, Pay 'n' Spray zera, suborno tira 1 estrela | OK | https://strategywiki.org/wiki/Grand_Theft_Auto:_San_Andreas/Stats ; https://gta.wiki/wiki/Wanted_Level_in_GTA_San_Andreas | — |
| cap-04:462 | [FATO PÚBLICO] GTA IV: círculo de busca; GTA V: cones de visão, estrelas piscam | OK | https://www.grandtheftwiki.com/Wanted_Level_in_GTA_IV ; https://gta.wiki/wiki/Wanted_Level_in_GTA_V | — |
| cap-04:494 | [INFERÊNCIA] desenho do wanted level sem afirmar sobre o código da Rockstar | OK | — | — |
| cap-04:888 | GPP "State": heroína de plataforma, FSM, hierárquica, autômato com pilha | OK | https://gameprogrammingpatterns.com/state.html | — |
| cap-05:105 / :535 | MDA, Hunicke, LeBlanc e Zubek, 2004 | OK | consagrado | — |
| cap-05:140 | [FATO PÚBLICO] Outlast (Red Barrels, 2013): visão noturna consome baterias | OK | consagrado | — |
| cap-05:142, :174, :232, :303 | [INFERÊNCIA] Outlast, futebol, horror: nenhuma apresentada como declaração de estúdio | OK | — | — |
| cap-05:209 | [FATO PÚBLICO] hit marker associado a Call of Duty | OK (popularizado por COD4) | https://www.thegamer.com/10-years-later-15-facts-about-call-of-duty-4-that-will-still-shock-you/ | — |
| cap-05:221 / :537 | Swink, *Game Feel: A Game Designer's Guide to Virtual Sensation* (2008) | OK (ressalva: a editora data a 1ª ed. em 09/03/2009, ©2009; varejo e Internet Archive registram fim de 2008) | https://shop.elsevier.com/books/game-feel/swink/978-0-12-374328-2 ; https://archive.org/details/game-feel | — |
| cap-06:204 / :792 | Mike Acton, *Data-Oriented Design and C++*, CppCon 2014 | OK | consagrado | — |
| cap-06:221 | [FATO PÚBLICO] Mass no City Sample (derivado de The Matrix Awakens) para multidões e tráfego | OK | https://dev.epicgames.com/documentation/unreal-engine/city-sample-project-unreal-engine-demonstration | — |
| cap-06:233 / :790 | GPP: capítulos Singleton, Component, Update Method, Service Locator, Data Locality | OK | consagrado | — |
| cap-06:420 | [FATO PÚBLICO] Control (Remedy, 2019), Northlight, Jesse Faden, Launch; Remedy apresentou a tecnologia em eventos | OK | https://gamedeveloper.com/programming/video-inside-the-graphics-tech-of-remedy-s-northlight-engine ; https://developer.nvidia.com/blog/ray-tracing-in-4as-metro-exodus-and-remedys-control | — |
| cap-06:450 | [INFERÊNCIA] contratos uniformes, sem afirmar nada sobre a Northlight | OK | — | — |
| cap-06:791 | GEA: "Runtime Gameplay Foundation Systems" | OK (Cap. 16) | https://bookcurl.com/products/game-engine-architecture-third-edition-9781138035454 | — |
| cap-07:70 | Build do código-fonte é necessária para servidor dedicado | OK | consagrado | — |
| cap-07:323 | "Perforce (Helix Core)" | CORRIGIDO (Helix Core virou P4 em março de 2025) | https://perforce.com/blog/vcs/introducing-the-p4-platform | "Perforce (Helix Core)" → "Perforce (P4, antigo Helix Core)" |
| cap-07:323 | A Epic usa Perforce; licença gratuita para equipes pequenas (com "verifique") | OK | consagrado | — |
| cap-07:586 | UE5 Style Guide (Allar, GitHub) | OK (repo existe; conteúdo UE5 no branch v2) | https://github.com/Allar/ue5-style-guide | — |
| cap-08:535 | [FATO PÚBLICO] GTA V: população ambiente aparece/desaparece ao redor do jogador | OK (observável) | consagrado | — |
| cap-08:537 | [INFERÊNCIA] spawn/despawn por relevância | OK | — | — |
| cap-09:284 | [FATO PÚBLICO] Quake (id, 1996): light styles a–z, "m" normal, taxa fixa; herdado por engines derivadas | OK | https://developer.valvesoftware.com/wiki/Lightstyle | — |
| cap-10:20 | Gameplay Framework vem de shooters multiplayer (linhagem Unreal Tournament) | OK | consagrado | — |
| cap-10:83 | PES 2011/FIFA 14 com motores próprios; eFootball na Unreal em 2021 | OK (eFootball 2022, UE4, set/2021) | https://www.pcgamer.com/pes-efootball-2022-release-date | — |
| cap-10:197 | Série Call of Duty não usa a Unreal | OK | consagrado | — |
| cap-10:477 | Exi (Cedric Neukirchen), *Unreal Engine Network Compendium* | CORRIGIDO (título atual é *Multiplayer Network Compendium*; o PDF original era o *UE4 Network Compendium*) | https://cedric-neukirchen.net/docs/multiplayer-compendium/introduction ; https://forums.unrealengine.com/t/free-multiplayer-network-compendium-gets-you-started-with-multiplayer-in-ue/64535 | título trocado por "*Multiplayer Network Compendium* (originalmente um PDF, o *UE4 Network Compendium*)" |
| cap-11:268 | `TObjectPtr` introduzido no UE5 | OK | consagrado | — |
| cap-11:446 | `UE_LOGFMT` em versões recentes do UE5 | OK | consagrado | — |
| cap-11:737 | Scott Meyers, *Effective Modern C++* (C++11/14) | OK | consagrado | — |
| cap-12:31 | VM do Blueprint, historicamente "Kismet VM" | OK | consagrado | — |
| cap-12:211 | Nativização de Blueprint removida no UE5 | OK | consagrado | — |
| cap-13:340 | Assinatura de `IsDataValid` mudou ao longo do UE5 (antes `TArray<FText>&`) | OK | consagrado | — |
| cap-14:188 | Escalas legadas yaw 2,5 / pitch −2,5; `bEnableLegacyInputScales` | OK | https://dev.epicgames.com/documentation/en-us/unreal-engine/python-api/class/InputSettings ; https://forums.unrealengine.com/t/why-does-the-inputyawscale-default-to-2-5/477043 | — |
| cap-14:218 | [FATO PÚBLICO] aim assist em COD e Apex; debate e ajustes públicos | OK | consagrado | — |
| cap-14:220 | [INFERÊNCIA] motivo do aim assist: apresentado como inferência | OK | — | — |
| cap-14:262 / :511 | EnhancedPlayerInput/EnhancedInputComponent como padrão; Enhanced Input substituiu o input legado no UE5 | OK | consagrado | — |
| cap-15:244 / :252 | [FATO PÚBLICO] GTA IV (2008): RAGE + euphoria (NaturalMotion); usado depois em RDR e Max Payne 3 | OK | https://en.wikipedia.org/wiki/Euphoria_(software) | — |
| cap-15:278 | [INFERÊNCIA] física de GTA IV, sem afirmar sobre RAGE/Euphoria | OK | — | — |
| cap-15:594 | UE5 trocou PhysX por Chaos | OK | consagrado | — |
| cap-15:616 | NaturalMotion/Euphoria: materiais públicos | OK (ressalva: a NaturalMotion parou de licenciar o euphoria em 2017) | https://en.wikipedia.org/wiki/Euphoria_(software) | — |

## Totais

- Linhas na tabela: 69 (alguns itens agrupados)
- OK: 67 | CORRIGIDO: 2 | REBAIXADO: 0 | REMOVIDO: 0
- Edições: parte-02/cap-07-conhecendo-a-engine.md:323; parte-02/cap-10-gameplay-framework.md:477. Uma linha cada, sem mudar a estrutura nem as cercas de código.
