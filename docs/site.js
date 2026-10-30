(() => {
  'use strict';
  const copy = {
    en: {
      skip:'Skip to content',nav:'Main navigation',bureau:'Recycling Bureau',navDownload:'Download',navGame:'Game',navBureau:'Paperwork',
      eyebrow:'ORIGINAL ABSENT · COPIES REPORT IN',title:'TAKE STACK',subtitle:'回响 / RECYCLING BUREAU',
      tagline:"Yesterday’s you. Today’s consumable.",intro:'A darkly comic paper-puppet auto-shooter.<br>Record your route. Fight beside your past.',fileLabel:'ISSUE NOTE',fileNote:'Take care of every copy of yourself.',
      heroAlt:'A tired paper clerk and a faded past copy beside a worn copy machine',idLabel:'You again. Welcome back.',stampTop:'APPROVED',stampBottom:'FOR REUSE',
      downloadTitle:'Pick up a playable copy',downloadHint:'Desktop build · Free · Offline single-player',installLink:'First launch & installation',releaseLink:'Release notes ↗',
      fieldEyebrow:'FIELD RECORD / ON THE FACTORY FLOOR',fieldTitle:'You. Yesterday’s you.<br>And the you before that.',fieldIntro:'Your weapons fire automatically. You decide where to go, what to keep, and when to retire your past.',
      videoAlt:'Silent actual in-game combat captured with automated controls',filmLabel:'IN-GAME FOOTAGE',filmCaption:'Actual game · Automated controls · Silent preview',filmAction:'Press play. See how the copies work.',
      loopOneTitle:'Leave a route',loopOne:'Each encounter records your path and loadout as an Echo.',loopTwoTitle:'Fight beside your past',loopTwo:'Your copy fights along its old route. Move around it, relay attacks, or put it to work on machines.',loopThreeTitle:'Decide how it ends',loopThree:'Wear leaves marks. Repair it, bind copies together, or retire one for a final skill.',
      paperworkEyebrow:'PLEASE FOLLOW PROCEDURE / PAPERWORK INCLUDED',paperworkTitle:'There’s more than one<br>way to make it through.',buildTitle:'Give today’s you a few options.',buildCopy:'35 weapons. Six equipment slots. Assemble duplicates, choose an evolution, or deploy a paper hound, turret or repair station. You still have to balance the books.',buildNote:'Regret is not included in the budget.',
      memoryTitle:'Leave a place for yesterday’s you.',memoryCopy:'File an Echo worth keeping. A useful route, a support tool or the right retirement skill all give a copy a reason to stay.',memoryNote:'An empty frame is a record, too.',
      shopAlt:'The real shop showing weapons, work orders, Echoes and explicit prices',archiveAlt:'The archive family wall showing stored roles and actual next-run values',
      dispatchTitle:'The bureau has other work for you.',dispatchCopy:'Deliver documents. Repair machines. Rescue workers. Negotiate. Stamps come down, paper jams, and signatures leave consequences.',dispatchLink:'See what’s in this release ↗',
      endingEyebrow:'FINAL PROCEDURE / SIGN IN PERSON',endingTitle:'The last page<br>needs your signature.',endingCopy:'Three acts. Twelve encounters. Three supervisors. The people you saved, the machines you fixed and the copies you kept are all on the page. Leave alone, leave together, or stay and take over?',endingAside:'Debt does not choose your ending.',signatureMark:'Still here. For now.',
      installEyebrow:'ISSUE INSTRUCTIONS / BEFORE YOUR SHIFT',installTitle:'Ready? Clock in.',installCopy:'Download the ZIP for your system, extract it and run the game. These links follow the latest published build.',
      macTitle:'First launch on macOS',macCopy:'The app has an ad-hoc integrity signature and is not notarized. Follow the included MAC_START_HERE.txt for the first launch.',otherTitle:'Windows, Linux & saves',otherCopy:'The Windows build is unsigned and may trigger SmartScreen. On Linux, give the executable permission to run. Version0.17 uses a new mid-run save format and needs a new run; permanent unlocks, settings and Echo archives remain.',
      controlsTitle:'Few controls. Plenty of decisions.',controlsCopy:'WASD / arrows to move; Shift for your role skill; E for machines; tap Space to retire an Echo, hold to choose one. Menus support mouse, keyboard and controller navigation.',allDownloads:'Downloads & release notes ↗',
      footerBureau:'RECYCLING BUREAU',footerSource:'Source',footerCredits:'Art & font credits',footerNote:'In active development. In-game media includes automated controls and scripted scenarios; long-term balance and target-device play are still being tested.'
    }
  };
  const originals = new Map();
  document.querySelectorAll('[data-i18n]').forEach(node => originals.set(node, node.innerHTML));
  document.querySelectorAll('[data-i18n-alt],[data-i18n-aria]').forEach(node => {
    originals.set(node, { alt:node.getAttribute('alt'),aria:node.getAttribute('aria-label') });
  });
  function apply(language) {
    const en = language === 'en';
    document.documentElement.lang = en ? 'en' : 'zh-CN';
    document.title = en ? 'Take Stack — Recycling Bureau' : '回响 / Take Stack — 废件回收局';
    document.querySelector('meta[name=description]').content = en ? 'A darkly comic paper-puppet auto-shooter. Record your route. Fight beside your past.' : '回响 / Take Stack：一款黑色幽默的纸偶自动射击 roguelite。录下路线，与过去的自己并肩作战。';
    document.querySelectorAll('[data-i18n]').forEach(node => { node.innerHTML = en ? copy.en[node.dataset.i18n] : originals.get(node); });
    document.querySelectorAll('[data-i18n-alt]').forEach(node => { node.alt = en ? copy.en[node.dataset.i18nAlt] : originals.get(node).alt; });
    document.querySelectorAll('[data-i18n-aria]').forEach(node => { node.setAttribute('aria-label', en ? copy.en[node.dataset.i18nAria] : originals.get(node).aria); });
    document.querySelectorAll('[data-image]').forEach(node => { node.src = `site-assets/${node.dataset.image}-${en ? 'en' : 'zh'}.png`; });
    document.querySelectorAll('[data-image-link]').forEach(node => { node.href = `site-assets/${node.dataset.imageLink}-${en ? 'en' : 'zh'}.png`; });
    const toggle = document.getElementById('language');
    toggle.textContent = en ? '中文' : 'EN';
    toggle.lang = en ? 'zh-CN' : 'en';
    toggle.href = en ? '?lang=zh' : '?lang=en';
    toggle.setAttribute('aria-label', en ? '切换到中文' : 'Switch to English');
  }
  const params = new URLSearchParams(location.search);
  apply(params.get('lang'));
  document.getElementById('language').addEventListener('click', event => {
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    event.preventDefault();
    const next = document.documentElement.lang === 'en' ? 'zh' : 'en';
    const url = new URL(location.href); url.searchParams.set('lang',next);
    history.replaceState(null,'',url);
    apply(next);
  });
})();
