from symmap import rev1
names = '''SwitchBank UpdateRodOrArrow UpdateSwordOrRod UpdateSwordShotOrMagicShot UpdateBoomerangOrFood
UpdateBombOrFire CheckLinkCollision CopyCommonCodeToRam AnimateLinkBase DrawObjectWithAnimAndSpecificSprites
CycleCurSpriteIndex SpriteOffsets GetCollidingTileMoving WieldSword WieldBoomerang WieldArrow WieldRod WieldBomb
WieldCandle CheckMonsterBoomerangOrFoodCollision CheckMonsterSwordShotOrMagicShotCollision
CheckMonsterBombOrFireCollision CheckMonsterSwordCollision CheckMonsterArrowOrRodCollision GetObjectMiddle
InitializeGameOrMode BeginUpdateWorld PlayAreaColumnAddrs WalkableTiles MakeSwordShot UpdateRockWall FindDoorTypeByDoorBit IsQuestSecretMismatch'''.split()
with open('../game.inc', 'w') as f:
    for n in names:
        b, a = rev1(n)
        f.write('%s = $%04X ; bank %d\n' % (n, a, b))
print(open('../game.inc').read())
