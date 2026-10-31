(() => {
  'use strict';
  const chinese = {
    "skip": "跳到正文",
    "bureau": "废件回收局",
    "navDownload": "下载",
    "navGame": "玩法",
    "navBureau": "局内手续",
    "eyebrow": "原件缺席 · 副本请就位",
    "title": "回响",
    "subtitle": "TAKE STACK",
    "tagline": "人没了，班还得上。",
    "intro": "一款黑色幽默的纸偶自动射击游戏。<br>录下路线，与过去的自己并肩作战。",
    "fileLabel": "领用须知",
    "fileNote": "替补人员：还是你。",
    "idLabel": "又是你。欢迎回来。",
    "stampTop": "准予",
    "stampBottom": "重新使用",
    "downloadTitle": "领取一份可玩的副本",
    "downloadHint": "桌面版 · 免费 · 离线单人",
    "installLink": "首次打开与安装说明",
    "releaseLink": "版本与更新记录 ↗",
    "fieldEyebrow": "现场记录 / FIELD RECORD",
    "fieldTitle": "你，昨天的你，<br>还有更旧的你。",
    "fieldIntro": "武器自动开火。你来决定走向哪里、留下什么，以及何时报废过去。",
    "filmLabel": "实机战斗",
    "filmCaption": "游戏内画面 · 自动操作 · 无声片段",
    "filmAction": "点击播放，看看副本怎么上班。",
    "loopOneTitle": "留下路线",
    "loopOne": "每场战斗，把你的路线与装备录成一张回响。",
    "loopTwoTitle": "和过去并肩",
    "loopTwo": "副本沿旧路线再战。你可以围绕它走位、接力，或操作机器。",
    "loopThreeTitle": "决定如何用完",
    "loopThree": "磨损会留下痕迹。修补、合订，或报废它，换取最后一次技能。",
    "paperworkEyebrow": "请按流程办理 / PAPERWORK INCLUDED",
    "paperworkTitle": "活下来的办法，<br>不止一种。",
    "buildTitle": "给今天的自己，配点办法。",
    "buildCopy": "35 把武器，六个装备槽。合成同类、选择进化，部署纸猎犬、炮台或修补站。预算有限，账要自己算。",
    "buildNote": "本局经费，不含后悔。",
    "memoryTitle": "给昨天的自己，留个位置。",
    "memoryCopy": "把值得留下的回响存进档案。好路线、辅助装备和合适的技能，都有被记住的理由。",
    "memoryNote": "空相框，也算一份记录。",
    "dispatchTitle": "局里还有别的工作。",
    "dispatchCopy": "送审、维修、救援、招安。印章会落下，设备会卡纸，签过的字会留下结果。",
    "dispatchLink": "查看这一版的内容 ↗",
    "endingEyebrow": "最终手续 / FINAL PROCEDURE",
    "endingTitle": "最后一页，<br>需要本人签字。",
    "endingCopy": "三幕，十二场，三位主管。救下的人、修好的设备、留下的副本，都在这张纸上。走出去、一起离开，还是留下接管？",
    "endingAside": "欠款不会替你选结局。",
    "signatureMark": "签名必填，心跳选填。",
    "installEyebrow": "领用说明 / BEFORE YOUR SHIFT",
    "installTitle": "准备好了，就开工。",
    "installCopy": "下载对应系统的 ZIP，解压后运行。下载入口会随已发布版本更新。",
    "macTitle": "macOS 首次打开",
    "macCopy": "安装包带本地完整性签名，尚未公证。首次打开请按包内 MAC_START_HERE.txt 操作。",
    "otherTitle": "Windows、Linux 与存档",
    "otherCopy": "Windows 包未签名，可能出现 SmartScreen 提示。Linux 请赋予程序执行权限。0.18.1 可继续0.17、0.18的中途存档；更早格式需新开对局，永久解锁、设置与回响档案保留。",
    "controlsTitle": "操作很少，决定不少。",
    "controlsCopy": "WASD / 方向键移动；Shift 使用角色技能；E 操作机器；轻点 Space 报废回响，按住选择。菜单支持键鼠和手柄导航。",
    "allDownloads": "打开下载与更新页 ↗",
    "footerBureau": "废件回收局",
    "footerSource": "源码",
    "footerCredits": "素材与字体来源",
    "footerNote": "持续开发中。页面实机素材包含自动操作与脚本化场景；长期平衡和目标设备体验仍在验证。",
    "nav": "主导航",
    "heroAlt": "疲惫的纸偶和过去的副本，站在旧复印设备前",
    "videoAlt": "真实游戏无声战斗片段，使用自动操作",
    "shopAlt": "商店展示武器、工作单、回响和明确价格",
    "archiveAlt": "副本家谱室展示真实归档角色与下一局数值"
};
  const originals = new Map();
  document.querySelectorAll('[data-i18n]').forEach(node => originals.set(node, node.innerHTML));
  document.querySelectorAll('[data-i18n-alt],[data-i18n-aria]').forEach(node => {
    originals.set(node, { alt:node.getAttribute('alt'),aria:node.getAttribute('aria-label') });
  });
  function apply(language) {
    const zh = language === 'zh' || language === 'zh-CN';
    document.documentElement.lang = zh ? 'zh-CN' : 'en';
    document.title = zh ? '回响 / Take Stack — 废件回收局' : 'Take Stack — Recycling Bureau';
    document.querySelector('meta[name=description]').content = zh ? '回响 / Take Stack：一款黑色幽默的纸偶自动射击 roguelite。录下路线，与过去的自己并肩作战。' : 'A darkly comic paper-puppet auto-shooter. Record your route. Fight beside your past.';
    document.querySelectorAll('[data-i18n]').forEach(node => { node.innerHTML = zh ? chinese[node.dataset.i18n] : originals.get(node); });
    document.querySelectorAll('[data-i18n-alt]').forEach(node => { node.alt = zh ? chinese[node.dataset.i18nAlt] : originals.get(node).alt; });
    document.querySelectorAll('[data-i18n-aria]').forEach(node => { node.setAttribute('aria-label', zh ? chinese[node.dataset.i18nAria] : originals.get(node).aria); });
    document.querySelectorAll('[data-image]').forEach(node => { node.src = `site-assets/${node.dataset.image}-${zh ? 'zh' : 'en'}.png`; });
    document.querySelectorAll('[data-image-link]').forEach(node => { node.href = `site-assets/${node.dataset.imageLink}-${zh ? 'zh' : 'en'}.png`; });
    const video = document.querySelector('.field-film video');
    if (video) {
      const source = video.querySelector('source');
      const nextSrc = `site-assets/${zh ? 'combat-loop.mp4' : 'combat-loop-en.mp4'}?v=motion`;
      const nextPoster = `site-assets/${zh ? 'combat-cover.png' : 'combat-cover-en.png'}?v=motion`;
      if (source.getAttribute('src') !== nextSrc) {
        source.setAttribute('src', nextSrc);
        video.poster = nextPoster;
        video.load();
      }
    }
    const toggle = document.getElementById('language');
    toggle.textContent = zh ? 'EN' : '中文';
    toggle.lang = zh ? 'en' : 'zh-CN';
    toggle.href = zh ? '?lang=en' : '?lang=zh';
    toggle.setAttribute('aria-label', zh ? 'Switch to English' : '切换到中文');
  }
  apply(new URLSearchParams(location.search).get('lang'));
  document.getElementById('language').addEventListener('click', event => {
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    event.preventDefault();
    const next = document.documentElement.lang === 'en' ? 'zh' : 'en';
    const url = new URL(location.href); url.searchParams.set('lang',next);
    history.replaceState(null,'',url);
    apply(next);
  });
})();
