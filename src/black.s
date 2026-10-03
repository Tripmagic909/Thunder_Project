| P-47II MD BLACK LABEL (裏モード): 難易度変更ルーチン
| Rank ($fffc06) = 3 のときだけ動作する. Rank 0-2 (Easy/Normal/Hard) は元の処理のまま.
|
    .equ RANK,          0xfffc06    | 0=Easy 1=Normal 2=Hard 3=BLACK
    .equ RANK_BLACK,    3
    .equ FRAME_CNT,     0xff500e    | 毎フレーム +1 されるカウンタ
    .equ BUL_MASK,      0xff78c6    | 敵弾プールの使用中ビット
    .equ BUL_POOL_N,    0xff4c08    | 敵弾プールの数 - 1 (通常時)
    .equ BOSS_MODE,     0xff6006    | ボス戦中は 0 以外
    .equ BUL_POOL_N_B,  0xff6014    | 敵弾プールの数 - 1 (ボス戦)

    .equ PAD_STATE,     0xffe032    | パッド (上位バイト: 押している / 下位: 押した瞬間)
    .equ SAVED_RANK,    0xfffc1e    | BLACK で遊ぶ前の Rank (未使用 RAM). 0xffff = なし
    .equ BUL_SPAWN_BODY, 0x0117ae   | 敵弾生成の本体 (元: 0x0117a6 movem / 0x0117aa lea の後)
    .equ HITBOX_TABLE,  0x001462    | 当たり判定の表 (種類 x 8 バイト: y0,y1,x0,x1)

| 調整値
    .equ BL_BULLET_SPEED, 179       | 敵弾の速さ (x/256. 179 = 約 0.7 倍)
    .equ BL_SPREAD_COS,   250       | 追加弾の角度 (約 12 度: cos*256, sin*256)
    .equ BL_SPREAD_SIN,   53
    .equ BL_SPREAD_FREE,  4         | 追加弾を出すのに必要な空きプール数

| ------------------------------------------------------------------
| 敵弾生成 (元: 0x0117a6). d2 = 弾の種類, d3/d4 = 速度 (1/16 ドット), a0 = 撃った敵.
| 元の処理は a2 (生成した弾) 以外のレジスタを保存する.
| BLACK: 速度を落とし, 左右に角度をずらした弾を 2 発追加する (プールに空きがあるとき).
BlackBulletSpawn:
    cmpi.w  #RANK_BLACK,RANK
    beq.s   1f
OrigBulletSpawn:
    movem.l d0-d7/a0-a1/a3-a6,-(sp)
    lea     0x00f192,a1
    jmp     BUL_SPAWN_BODY
1:  movem.l d0-d1/d3-d7,-(sp)
    muls.w  #BL_BULLET_SPEED,d3
    asr.l   #8,d3
    muls.w  #BL_BULLET_SPEED,d4
    asr.l   #8,d4
    bsr.s   OrigBulletSpawn         | 本来の弾 (遅くしたもの)
    move.l  a2,-(sp)
    bsr.s   FreeBulletSlots
    cmpi.w  #BL_SPREAD_FREE,d0
    blt.s   9f
    move.w  d3,d6                   | 元の vx
    move.w  d4,d7                   | 元の vy
    | +角度: vx' = (vx*c - vy*s)/256, vy' = (vx*s + vy*c)/256
    move.w  d6,d3
    muls.w  #BL_SPREAD_COS,d3
    move.w  d7,d0
    muls.w  #BL_SPREAD_SIN,d0
    sub.l   d0,d3
    asr.l   #8,d3
    move.w  d6,d4
    muls.w  #BL_SPREAD_SIN,d4
    move.w  d7,d0
    muls.w  #BL_SPREAD_COS,d0
    add.l   d0,d4
    asr.l   #8,d4
    bsr.s   OrigBulletSpawn
    | -角度: vx' = (vx*c + vy*s)/256, vy' = (-vx*s + vy*c)/256
    move.w  d6,d3
    muls.w  #BL_SPREAD_COS,d3
    move.w  d7,d0
    muls.w  #BL_SPREAD_SIN,d0
    add.l   d0,d3
    asr.l   #8,d3
    move.w  d7,d4
    muls.w  #BL_SPREAD_COS,d4
    move.w  d6,d0
    muls.w  #BL_SPREAD_SIN,d0
    sub.l   d0,d4
    asr.l   #8,d4
    bsr.s   OrigBulletSpawn
9:  move.l  (sp)+,a2
    movem.l (sp)+,d0-d1/d3-d7
    rts

| 敵弾プールの空き数 -> d0 (d1 使用)
FreeBulletSlots:
    move.w  BUL_POOL_N,d1
    tst.w   BOSS_MODE
    beq.s   1f
    move.w  BUL_POOL_N_B,d1
1:  moveq   #0,d0
    move.l  d2,-(sp)
    move.l  BUL_MASK,d2
2:  btst    d1,d2
    bne.s   3f
    addq.w  #1,d0
3:  dbra    d1,2b
    move.l  (sp)+,d2
    rts

| ------------------------------------------------------------------
| ザコ敵の耐久力 (元: 0x010390 move.w (a3)+,$24(a2) / move.l (a3)+,$26(a2))
| BLACK: 1.5 倍 (1 以上 0x5000 未満のときだけ)
BlackEnemyHp:
    move.w  d3,-(sp)
    move.w  (a3)+,d3
    cmpi.w  #RANK_BLACK,RANK
    bne.s   1f
    bsr.s   Hp150
1:  move.w  d3,0x24(a2)
    move.l  (a3)+,0x26(a2)
    move.w  (sp)+,d3
    rts

| d3 を 1.5 倍 (1 以上 0x5000 未満のとき)
Hp150:
    cmpi.w  #1,d3
    blt.s   1f
    cmpi.w  #0x5000,d3
    bge.s   1f
    move.w  d3,-(sp)
    lsr.w   #1,d3
    add.w   (sp)+,d3
1:  rts

| ------------------------------------------------------------------
| ボスの耐久力 (元: 0x011e46-0x011e54. Rank 別の 3 値の表から読む)
| BLACK: Hard の値の 1.5 倍 (表は 3 値しか無いので範囲外を読まないように)
BlackBossHp:
    move.w  RANK,d0
    cmpi.w  #RANK_BLACK,d0
    bne.s   1f
    move.w  d3,-(sp)
    move.w  4(a1),d3
    bsr.s   Hp150
    move.w  d3,0x24(a0)
    move.w  (sp)+,d3
    bra.s   2f
1:  add.w   d0,d0
    move.w  (a1,d0.w),0x24(a0)
2:  addq.w  #6,a1
    rts

| ------------------------------------------------------------------
| 当たり判定の表の参照 (元: 0x001fd0 lea $1462(pc),a6 / lsl.w #3,d4 / adda.w d4,a6)
| BLACK: 自機 (種類 1) の当たり判定を小さくする
BlackHitbox:
    lea     HITBOX_TABLE,a6
    cmpi.w  #RANK_BLACK,RANK
    bne.s   1f
    cmpi.w  #1,d4
    bne.s   1f
    lea     BlackPlayerBox,a6
    rts
1:  lsl.w   #3,d4
    adda.w  d4,a6
    rts

| 自機の当たり判定 (元: y 6..9, x 13..28 -> BLACK: y 6..9, x 18..23)
BlackPlayerBox:
    dc.w    6,9,18,23

| ------------------------------------------------------------------
| ザコ敵の移動 (元: 0x0105b8-0x0105cb 位置 += 速度, 継続フレーム -1)
| BLACK: 4 フレームに 1 回もう 1 歩進める (軌道はそのままで約 1.25 倍速)
BlackEnemyMove:
    move.w  0x14(a0),d4
    add.w   d4,0x1a(a0)
    move.w  0x16(a0),d5
    add.w   d5,0x1c(a0)
    subq.w  #1,0x12(a0)
    cmpi.w  #RANK_BLACK,RANK
    bne.s   9f
    btst    #0,FRAME_CNT+1
    bne.s   9f
    btst    #1,FRAME_CNT+1
    bne.s   9f
    tst.w   0x12(a0)
    beq.s   9f                      | この歩で区切りになるなら追加しない
    add.w   d4,0x1a(a0)
    add.w   d5,0x1c(a0)
    subq.w  #1,0x12(a0)
9:  rts

| ------------------------------------------------------------------
| タイトルで START を選んだとき (元: 0x016e36 move.w #4,$ff5202)
| 試作: C を押しながら START で BLACK LABEL (左+C は元の隠しメニュー)
BlackTitleStart:
    move.w  #4,0xff5202
    move.w  d0,-(sp)
    move.w  PAD_STATE,d0
    andi.w  #0x2400,d0
    cmpi.w  #0x2000,d0
    bne.s   1f
    cmpi.w  #RANK_BLACK,RANK
    beq.s   1f
    move.w  RANK,SAVED_RANK
    move.w  #RANK_BLACK,RANK
1:  move.w  (sp)+,d0
    rts

| タイトル初期化時: BLACK で遊んだ後なら元の Rank に戻す
BlackRestoreRank:
    cmpi.w  #RANK_BLACK,RANK
    bne.s   1f
    move.w  SAVED_RANK,RANK
    cmpi.w  #2,RANK
    bls.s   1f
    move.w  #1,RANK
1:  rts
