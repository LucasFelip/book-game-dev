# Fact-check grupo 3 (parte-05 cap-33 a cap-42; parte-06 cap-43)

Status: concluído (12/11/2026). Limitações: cota de WebSearch esgotada no meio do trabalho; vários sites (Epic docs, GDC Vault, gameaipro PDFs) com ECONNRESET; Firecrawl atingiu o limite diário.

Resumo: 31 linhas na tabela: 25 OK (1 com ressalva; 1 linha cobre as 8 INFERÊNCIAS), 3 CORRIGIDO, 1 REBAIXADO, 0 REMOVIDO, 2 não checados (API ou comportamento de código).

| arquivo:linha | afirmação (curta) | veredito | fonte (URL) | mudança feita |
|---|---|---|---|---|
| cap-41:132 | GOAP apresentado por Orkin "a partir do trabalho em F.E.A.R." | CORRIGIDO | https://pages.cs.wisc.edu/~dyer/cs540/handouts/gdc2006_orkin_jeff_fear.pdf (refs: Orkin 2003, AIGPW2, 217-228) | GOAP publicado no AI Game Programming Wisdom 2 (2003), antes de F.E.A.R.; ficou famoso com F.E.A.R. |
| cap-41:132 | Palestra "Three States and a Plan: The A.I. of F.E.A.R.", GDC 2006; FSM pequena + planejador | OK | mesma URL | — |
| cap-41:132 | Orkin: impressão de coordenação vinha das falas ("flanqueando!") | CORRIGIDO | mesma URL (seção sobre squad behaviors e dialogue) | Artigo diz que não havia comportamentos complexos de esquadrão; flanco emergia de ir à cobertura; falas sinalizavam coordenação. Exemplos trocados por falas citadas no artigo |
| cap-41:156 | Killzone 2: bots MP com HTN, conferência de Game AI 2009 | OK | https://www.slideshare.net/guerrillagames/killzone-2-multiplayer-bots ; https://gamedev.net/tutorials/industry/event-coverage/paris-game-ai-conference-r2646 | — (Paris Game AI Conference, jun/2009) |
| cap-41:156 | Troy Humphreys, "Exploring HTN Planners through Example", Game AI Pro | OK | http://www.gameaipro.com/ (GAIP1, cap. 12) | — |
| cap-33:430 | Game AI Pro (Rabin), volumes grátis em gameaipro.com | OK | http://www.gameaipro.com/ | — |
| cap-36:789; 37:551; 39:461; 40:536; 41:469; 42:582 | Game AI Pro tem capítulos sobre percepção, BTs, posição tática, utilidade, HTN, mapas de influência, esquadrões/ataques, pacing | OK | http://www.gameaipro.com/ (ex.: Walsh/Splinter Cell Blacklist; Francis, pitfalls BT; Jack, Tactical Position Selection; Lewis/Mark, influence maps; Dawe, NPC attacks; Brewer, pacing Warframe) | — |
| cap-40:134,535 | Dill e Mark, "Improving AI Decision Modeling Through Utility Theory", GDC 2010 | OK | https://gdcvault.com/play/1012410 | — |
| cap-40:134,534 | Dave Mark, *Behavioral Mathematics for Game AI*, 2009 | OK | https://www.thevideogamelibrary.org/book/behavioral-mathematics-for-game-ai | — |
| cap-42:103,581 | Michael Booth, "The AI Systems of Left 4 Dead" (2009); AI Director, L4D (Valve, 2008) | OK | https://cdn.fastly.steamstatic.com/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf | — |
| cap-37:239,550 | Damian Isla, "Handling Complexity in the Halo 2 AI", GDC 2005; Halo 2 (Bungie, 2004); decisão hierárquica | OK | https://gamedeveloper.com/programming/gdc-2005-proceeding-handling-complexity-in-the-i-halo-2-i-ai | — |
| cap-43:77,326 | Clint Hocking cunhou "ludonarrative dissonance", 2007, sobre BioShock, blog Click Nothing | OK | https://www.clicknothing.com/click_nothing/2007/10/ludonarrative-d.html ; https://en.wikipedia.org/wiki/Ludonarrative_dissonance | — |
| cap-35:401 | Recast & Detour: "repositório público de Mikko Mononen" | CORRIGIDO | https://github.com/recastnavigation/recastnavigation ; https://raw.githubusercontent.com/recastnavigation/recastnavigation/main/License.txt | Repositório é da organização recastnavigation; Mononen é o criador (copyright 2009). Texto: "repositório público *recastnavigation*; biblioteca criada por Mikko Mononen" |
| cap-35:401 | Recast usada pela Unreal | OK | https://github.com/recastnavigation/recastnavigation (README cita Unreal) | — |
| cap-33:207 | Outlast (Red Barrels, 2013): sem combate, fugir, esconder-se em armários, pular obstáculos | OK | https://en.wikipedia.org/wiki/Outlast_(video_game) | — (portas, camas, busca e perseguições roteirizadas: observáveis jogando; não constam na fonte) |
| cap-36:202 | Outlast: visão noturna da câmera | OK | https://en.wikipedia.org/wiki/Outlast_(video_game) | — |
| cap-36:202 | Amnesia: TDD (Frictional, 2010): escuro esconde, escuro prolongado afeta sanidade com efeitos | OK | https://en.wikipedia.org/wiki/Amnesia:_The_Dark_Descent | — (música de perigo: fonte cita "danger music" com inimigos próximos) |
| cap-43:123 | Alan Wake (Remedy, 2010): episódios, "Previously on", páginas de manuscrito que prenunciam eventos | OK | https://en.wikipedia.org/wiki/Alan_Wake | — |
| cap-34:192 | Pac-Man (Namco, 1980): modos e alvo próprio por fantasma | OK | https://en.wikipedia.org/wiki/Pac-Man | — (modo scatter: consagrado, documentado no Pac-Man Dossier; não reconfirmado por falha de rede) |
| cap-34:642 | Nystrom, Game Programming Patterns, cap. "State": FSM hierárquica e autômato com pilha | OK | https://gameprogrammingpatterns.com/state.html | — |
| cap-34:643 | Harel, *Statecharts: A Visual Formalism for Complex Systems* (1987) | OK | consagrado (Science of Computer Programming 8(3), 1987) | — |
| cap-33:429 etc. | Millington, *AI for Games* (3ª ed.) | OK | consagrado (CRC Press, 2019) | — |
| cap-38:46 | Arquitetura de quadro-negro usada no Hearsay-II, anos 1970 | OK | https://en.wikipedia.org/wiki/Blackboard_system (Hearsay II entre os primeiros sistemas) | — |
| cap-40:71 | Produto com fator de compensação, "por exemplo, nos trabalhos de Dave Mark" | OK (ressalva) | https://github.com/apoch/curvature (IAUS de Dave Mark, considerações multiplicadas) | Sem mudança: texto já é cauteloso; a fórmula de compensação não foi reconfirmada na web (busca esgotada / falha de rede) |
| cap-37:262; cap-33:114,146; cap-34:645 | StateTree: sistema da UE5, HFSM + seleção por condições, integra Mass/Smart Objects | OK | https://dev.epicgames.com/documentation (StateTree) — conhecimento consagrado | — |
| cap-33:432; cap-43:327 | GDC tem AI Summit e Narrative Summit | OK | https://gdcvault.com | — |
| cap-41:168 | Barks em shooters (CoD, Battlefield) | OK | observável jogando | — |
| cap-36:153 | Assinatura de CanBeSeenFrom mudou no UE5 | NÃO CHECADO | docs da Epic inacessíveis (ECONNRESET) | — (afirmação vaga, de API) |
| cap-39:89 | EQS reordena testes por Cost, filtros antes de pontuação | NÃO CHECADO | comportamento de código; o próprio texto manda conferir no fonte | — |
| — | INFERÊNCIA (33:209, 34:194, 36:204, 37:241, 40:136, 41:170, 42:105, 43:125) | OK | — | Nenhuma apresentada como declaração de estúdio |
| cap-37:152 | Helpers InitializeNodeMemory/CleanupNodeMemory: "antes da 5.2" era à mão | REBAIXADO | Não confirmado (docs da Epic inacessíveis; API atual cita os helpers, sem versão) — https://dev.epicgames.com/documentation/unreal-engine/API/Runtime/AIModule/UBTNode | "versões anteriores à 5.2" -> "versões mais antigas da engine, sem esses helpers" |
