# Fact-check: grupo 2 (parte-03 cap-16 a 24; parte-04 cap-25 a 32)

Status: concluído (2026-11-12). Linhas referem-se ao texto antes das edições (as edições não mudaram a contagem de linhas).

| arquivo:linha | afirmação (curta) | veredito | fonte (URL) | mudança feita |
|---|---|---|---|---|
| cap-16:208 | GTA V (Rockstar, 2013): 3 protagonistas, troca com câmera aérea, personagem achado em atividade | OK | consagrado (observável jogando) | — |
| cap-16:138 | CheatManager instanciado em builds de desenvolvimento, não em Shipping por padrão | OK | comportamento da engine (UE_WITH_CHEAT_MANAGER) | — |
| cap-17:256 | FIFA/PES têm atributos de movimento por atleta | OK | consagrado | — |
| cap-17:258 | eFootball em Unreal desde 2021; outros usaram motores próprios | OK | https://www.pcgamer.com/pes-efootball-2022-release-date ; https://www.techradar.com/news/how-the-pro-evolution-of-konamis-efootball-came-to-be | — |
| cap-17:772 | Dunn e Parberry, *3D Math Primer for Graphics and Game Development* | OK | consagrado | — |
| cap-18:166 | Outlast (Red Barrels, 2013): sem combate, armários/camas, filmadora com visão noturna e baterias | OK | consagrado (observável jogando) | — |
| cap-18:503 | "API de camera shakes mudou no UE5" | CORRIGIDO | https://community.gamedev.tv/t/camerashake-is-now-matineecamerashake-as-of-4-26/153515 ; https://docs.unrealengine.com/5.1/en-US/PythonAPI/class/LegacyCameraShake.html ; https://forums.unrealengine.com/t/cant-compile-camera-shakes-in-5-1/696508 | mudança datada na 4.26 (padrões; UCameraShake → UMatineeCameraShake) e renomeação para ULegacyCameraShake na 5.1 |
| cap-18:523 | Nesky, "50 Game Camera Mistakes" (GDC 2014) | CORRIGIDO | https://gdcvault.com/play/1020460/50-Camera | título conforme o GDC Vault: "50 Camera Mistakes" |
| cap-18:524 | Game Accessibility Guidelines (gameaccessibilityguidelines.com) | OK | consagrado | — |
| cap-19:241 | Frictional (Amnesia TDD 2010, Penumbra antes): interação física por gestos | OK | consagrado (observável jogando) | — |
| cap-19:1076 | Lyra: interação por interface + gameplay ability | OK | https://dev.epicgames.com/documentation/en-us/unreal-engine/lyra-sample-game-interaction-system-in-unreal-engine | — |
| cap-20:225 | CoD/Battlefield mostram estatísticas e acessórios com trade-offs | OK | consagrado | — |
| cap-20:931 | "compare a arma do template" First Person | CORRIGIDO | https://www.unrealengine.com/en-US/news/updated-game-templates-for-unreal-engine-5-6available-now ; https://dev.epicgames.com/documentation/unreal-engine/variants-in-game-templates | a partir da 5.6 a variante base (None) não traz arma; indicada a variante Arena Shooter |
| cap-20:933 | Lyra: armas sobre GAS | OK | consagrado (código da Lyra) | — |
| cap-21:89 | TTK é métrica muito discutida | OK | consagrado | — |
| cap-21:132 | Amnesia: sem armas; sanidade afetada por escuridão e por olhar monstros | OK | consagrado (observável jogando) | — |
| cap-21:134 | Alan Wake (Remedy, 2010): luz remove escuridão, depois arma; baterias, munição, sinalizadores | OK | consagrado (observável jogando) | — |
| cap-21:417 | Schell, *The Art of Game Design* | OK | consagrado | — |
| cap-22:114 | Vida regenerativa popularizada por CoD 2 (2005); Halo com escudos recarregáveis | OK | https://en.wikipedia.org/wiki/Call_of_Duty_2 ; https://www.gamesradar.com/stop-drop-and-heal-history-regenerating-health | — |
| cap-22:64/783 | GAS usado na Lyra (vida e dano) | OK | consagrado (código da Lyra) | — |
| cap-23:153 | GAS tem loose gameplay tags com contagem | OK | API (AddLooseGameplayTag com Count) | — |
| cap-23:176 | Control (Remedy, 2019): Oldest House, Hiss, Control Points como checkpoint e viagem rápida | OK | consagrado (observável jogando) | — |
| cap-24:148/493 | Lyra: plugin Gameplay Message Router, canais por Gameplay Tag, mensagens por struct | OK | consagrado (código da Lyra) | — |
| cap-24:156 | Narração de PES/FIFA reage a lances; narradores brasileiros em várias edições | OK | consagrado | — |
| cap-24:494 | Nystrom, GPP: capítulos "Observer" e "Event Queue" | OK | https://gameprogrammingpatterns.com | — |
| cap-25:118 | Apex (Respawn, 2019) slide/escalada; MW 2019 slide, tactical sprint, mounting; SWBF II (DICE, 2017) | OK | consagrado (observável jogando) | — |
| cap-25:459 | Swink, *Game Feel*: capítulos de métricas de input e de resposta | OK | https://en.wikipedia.org/wiki/Game_feel ; https://perlego.com/book/1696576/game-feel-a-game-designers-guide-to-virtual-sensation-pdf | — |
| cap-25:461 | Character.cpp CanJumpInternal_Implementation/CheckJumpInput; CMC DoJump | OK | código da engine | — |
| cap-26:128 | MW 2019 introduziu o Gunsmith; acessórios limitados com prós e contras | OK | https://www.gamesradar.com/call-of-duty-modern-warfare-gunsmith-system ; https://mp1st.com/news/call-of-duty-modern-warfare-gunsmith-tease-confirms-guns-will-feature-5-attachments | — |
| cap-26:653 | Lyra: instâncias de equipamento e fragmentos de item | OK | consagrado (código da Lyra) | — |
| cap-27:184 | Reclamações recorrentes sobre hit registration | OK | consagrado | — |
| cap-27:62 | [INFERÊNCIA] cano como origem em terceira pessoa | OK (rótulo adequado) | — | — |
| cap-28:79 | Battlefield: balística com tempo de voo e queda | OK | consagrado (observável jogando) | — |
| cap-28:641 | "o projétil do template First Person" | CORRIGIDO | https://www.unrealengine.com/en-US/news/updated-game-templates-for-unreal-engine-5-6available-now ; https://dev.epicgames.com/documentation/unreal-engine/variants-in-game-templates | indicada a variante Arena Shooter para 5.6+ |
| cap-29:117 | MW 2019 elogiado pela sensação e pelo som das armas | OK | https://giantbomb.com/reviews/call-of-duty-modern-warfare-review ; https://www.thegamer.com/modern-warfare-best-sound-design-2019/ | — |
| cap-29:540 | Swink, *Game Feel*: capítulo sobre "polish" | OK | https://en.wikipedia.org/wiki/Game_feel (capítulo "Polish Metrics") | — |
| cap-29:84 | [INFERÊNCIA] recuo padronizado em shooters competitivos | OK (rótulo adequado) | — | — |
| cap-30:157 | Taken falam frases ligadas às vidas anteriores; escuridão visível se dissipa sob a luz | OK | https://tvtropes.org/pmwiki/pmwiki.php/YMMV/AlanWake ; https://alanwake.fandom.com/wiki/Emil_Hartman | — |
| cap-30:157 | "o lenhador fala de trabalho, por exemplo" | REBAIXADO | sem fonte específica (Giant Bomb cita conversa sobre paisagem, restaurantes, segurança) | exemplo específico trocado por "restos de conversas do cotidiano, sobre a cidade ou o trabalho" |
| cap-31:99 | CoD Dominação (A, B, C; limite de pontos ou tempo); BF Conquista com tickets, reanimação não custa ticket | OK | consagrado (observável jogando) | — |
| cap-31:632 | doc "Programming Subsystems (incluindo UTickableWorldSubsystem)" | REBAIXADO | https://dev.epicgames.com/documentation/unreal-engine/API/Runtime/Engine/UTickableWorldSubsystem | não confirmado que a página-guia cubra a classe; apontado para a referência de API |
| cap-31:633 | Lyra tem modos de eliminação e captura de pontos (Control) | OK | consagrado (Lyra) | — |
| cap-32:137 | Battlefield 4 com 64 jogadores em várias plataformas | OK | https://gamingbolt.com/battlefield-4-dice-prioritized-64-players-on-next-gen-consoles-over-1080p ; https://www.gamespark.jp/article/2013/09/27/43737.html | — |
| cap-32:137 | Campanhas antigas de CoD com inimigos infinitos até o jogador avançar (observação de jogadores) | OK | consagrado | — |
| cap-32:836 | Michael Booth, "The AI Systems of Left 4 Dead" (Valve, 2009) | OK | https://cdn.fastly.steamstatic.com/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf | — |
| cap-32:837 | Nystrom, GPP, "Object Pool" (gratuito no site) | OK | https://gameprogrammingpatterns.com | — |
| todos | Itens [INFERÊNCIA] não apresentados como declaração de estúdio | OK | — | — |
