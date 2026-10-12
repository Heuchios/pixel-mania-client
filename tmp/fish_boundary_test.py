from pathlib import Path
p=Path('scripts/test_fish_market.js');t=p.read_text();needle='  // Two shard clients see the same row.';i=t.index(needle);t=t[:i]+'''  // New catches respect the 999 kg boundary, including grandfathered stacks.
  for (const owned of [9989, 9990, 15000]) {
    context.FishMarket = {...Market, catchAmount:()=>1};
    sessions.set('p',{session_id:'cap',world:'START',expires_at:Date.now()+10000,item_id:'guppy',fish_id:'guppy',item_category:'fish'});
    state={fish_inventory:{guppy:owned},currency_inventory:{gem:0}};
    commits=0;
    await context.handleFishingCompleteTransaction({}, {id:'p',world:'START',account_username:'p'}, {success:true,session_id:'cap'});
    assert.equal(commits, owned < 9990 ? 1 : 0);
    assert.equal(state.fish_inventory.guppy, owned < 9990 ? 9990 : owned);
  }
''' +t[i:];p.write_text(t)
