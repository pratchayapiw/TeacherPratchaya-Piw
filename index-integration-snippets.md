# โค้ดเชื่อมระบบ Email/Password กับ `index.html`

ไฟล์ `index-auth.html` ยังไม่ได้แทนที่หน้าเว็บจริงโดยอัตโนมัติ ให้สำรอง `index.html` ก่อน แล้วแก้ตามรายการนี้

## A. เพิ่มไฟล์ JavaScript ก่อนสคริปต์ `appjs`

ค้นหา:
```html
<script id="appjs">
```

วางก่อนบรรทัดนั้น:
```html
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
<script src="./supabase-config.js"></script>
<script src="./auth.js"></script>
```

## B. เพิ่ม CSS ปุ่มแสดง/ซ่อนรหัสผ่าน

วางต่อจาก `.fld{display:grid;gap:6px}`:
```css
.input-wrap{position:relative;display:flex;align-items:center}
.input-wrap input{padding-right:76px}
.pw-toggle{position:absolute;right:8px;top:50%;transform:translateY(-50%);border:0;background:transparent;color:var(--rose-deep);font-size:12px;font-weight:700;padding:5px 7px;cursor:pointer}
.text-link{border:0;background:transparent;color:var(--rose-deep);font:inherit;font-size:13px;text-align:left;padding:2px 0;cursor:pointer}
```

## C. เปลี่ยนตัวแปรและ REST helper

แทนที่บรรทัด `var SB_URL=...` และฟังก์ชัน `sb(path,opt)` เดิมด้วย:
```javascript
var SB_URL=window.TP_SUPABASE_CONFIG.url,
    SB_KEY=window.TP_SUPABASE_CONFIG.anonKey,
    HUB_ID='main',base=null,remote=null;

function sb(path,opt){
  opt=opt||{};
  var token=window.TP_AUTH&&window.TP_AUTH.getAccessToken();
  opt.headers=Object.assign({
    'apikey':SB_KEY,
    'Authorization':'Bearer '+(token||SB_KEY),
    'Content-Type':'application/json'
  },opt.headers||{});

  return fetch(SB_URL+'/rest/v1/'+path,opt).then(function(r){
    return r.text().then(function(t){
      var j=null;
      try{j=t?JSON.parse(t):null;}catch(e){}
      if(!r.ok){
        var m=(j&&(j.message||j.hint||j.details))||('HTTP '+r.status);
        throw new Error(m);
      }
      return j;
    });
  });
}
```

## D. แทนที่ `save()`, `loginForm()` และ `pinForm()` เดิม

```javascript
function save(){
  if(!canSave||saving)return;
  saving=true;msg='กำลังบันทึก…';renderBar();

  var filter='hub_pages?id=eq.'+encodeURIComponent(HUB_ID);
  if(base)filter+='&updated_at=eq.'+encodeURIComponent(base);

  sb(filter,{
    method:'PATCH',
    headers:{'Prefer':'return=representation'},
    body:JSON.stringify({data:S,updated_at:new Date().toISOString()})
  }).then(function(rows){
    saving=false;
    if(!rows||!rows.length){
      msg='ข้อมูลถูกแก้ไขจากอีกเครื่อง กรุณาโหลดหน้าใหม่ก่อนบันทึก';
      renderBar();return;
    }
    base=rows[0].updated_at;dirty=0;msg='บันทึกแล้ว';renderBar();
    setTimeout(function(){if(!dirty){msg='';renderBar();}},2500);
  },function(e){saving=false;msg=errText(e);renderBar();});
}

function loginForm(){
  form('เข้าสู่ระบบครู',[
    {k:'email',l:'อีเมล',t:'email',req:1,ph:'pratchaya.piw@gmail.com'},
    {k:'password',l:'รหัสผ่าน',req:1,pw:1}
  ],{},function(o){
    var btn=$m.querySelector('[type=submit]');
    btn.disabled=true;
    $('e-email').textContent='';
    $('e-password').textContent='';

    window.TP_AUTH.signIn(o.email,o.password).then(function(){
      canSave=true;edit=true;closeF();render();
    }).catch(function(e){
      btn.disabled=false;
      $('e-password').textContent=/Invalid login credentials/i.test(String(e.message))
        ?'อีเมลหรือรหัสผ่านไม่ถูกต้อง':errText(e);
    });
    return false;
  });

  var forgot=document.createElement('button');
  forgot.type='button';
  forgot.className='text-link';
  forgot.textContent='ลืมรหัสผ่าน?';
  forgot.setAttribute('data-f','forgot');
  $m.querySelector('.btns').parentNode.insertBefore(forgot,$m.querySelector('.btns'));
}

function forgotForm(prefill){
  form('กู้คืนรหัสผ่าน',[
    {k:'email',l:'อีเมลที่ลงทะเบียน',t:'email',req:1,ph:'pratchaya.piw@gmail.com'}
  ],{email:prefill||''},function(o){
    var btn=$m.querySelector('[type=submit]');
    btn.disabled=true;$('e-email').textContent='';
    window.TP_AUTH.sendPasswordReset(o.email).then(function(){
      btn.disabled=false;
      $('e-email').textContent='ส่งลิงก์กู้คืนแล้ว กรุณาตรวจสอบกล่องจดหมายและ Spam';
    }).catch(function(e){
      btn.disabled=false;$('e-email').textContent=errText(e);
    });
    return false;
  });
}

function pinForm(){
  form('เปลี่ยนรหัสผ่าน',[
    {k:'nw',l:'รหัสผ่านใหม่ (อย่างน้อย 8 ตัวอักษร)',req:1,pw:1},
    {k:'nw2',l:'ยืนยันรหัสผ่านใหม่',req:1,pw:1}
  ],{},function(o){
    if(o.nw.length<8){$('e-nw').textContent='รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร';return false;}
    if(o.nw!==o.nw2){$('e-nw2').textContent='รหัสผ่านใหม่ไม่ตรงกัน';return false;}

    var btn=$m.querySelector('[type=submit]');
    btn.disabled=true;
    window.TP_AUTH.updatePassword(o.nw).then(function(){
      closeF();
      msg='เปลี่ยนรหัสผ่านเรียบร้อยแล้ว';renderBar();
    }).catch(function(e){
      btn.disabled=false;$('e-nw').textContent=errText(e);
    });
    return false;
  });
}

var recoveryShown=false;
function recoveryForm(){
  if(recoveryShown)return;
  recoveryShown=true;
  form('ตั้งรหัสผ่านใหม่',[
    {k:'nw',l:'รหัสผ่านใหม่ (อย่างน้อย 8 ตัวอักษร)',req:1,pw:1},
    {k:'nw2',l:'ยืนยันรหัสผ่านใหม่',req:1,pw:1}
  ],{},function(o){
    if(o.nw.length<8){$('e-nw').textContent='รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร';return false;}
    if(o.nw!==o.nw2){$('e-nw2').textContent='รหัสผ่านไม่ตรงกัน';return false;}

    var btn=$m.querySelector('[type=submit]');
    btn.disabled=true;
    window.TP_AUTH.updatePassword(o.nw).then(function(){
      closeF();
      history.replaceState({},document.title,window.location.pathname);
      msg='ตั้งรหัสผ่านใหม่เรียบร้อยแล้ว';renderBar();
    }).catch(function(e){
      btn.disabled=false;$('e-nw').textContent=errText(e);
    });
    return false;
  });
}
```

## E. ปรับส่วนสร้าง input ใน `form()`

ค้นหาบรรทัดเดิม:
```javascript
else inp='<input id="'+id+'" type="'+(f.pw?'password':'text')+'" value="'+esc(val)+'"'+(f.req?' required':'')+(f.ph?' placeholder="'+esc(f.ph)+'"':'')+(f.k==='url'?' inputmode="url" autocapitalize="off" spellcheck="false"':'')+'>';
```

แทนด้วย:
```javascript
else {
  var inputType=f.pw?'password':(f.t==='email'?'email':'text');
  var attrs=(f.req?' required':'')+(f.ph?' placeholder="'+esc(f.ph)+'"':'')+
    (f.t==='email'?' autocomplete="username" autocapitalize="off" spellcheck="false"':'')+
    (f.pw?' autocomplete="current-password"':'')+
    (f.k==='url'?' inputmode="url" autocapitalize="off" spellcheck="false"':'');
  inp=f.pw
    ?'<div class="input-wrap"><input id="'+id+'" type="password" value="'+esc(val)+'"'+attrs+'><button type="button" class="pw-toggle" data-toggle-pw="'+id+'" aria-label="แสดงรหัสผ่าน">แสดง</button></div>'
    :'<input id="'+id+'" type="'+inputType+'" value="'+esc(val)+'"'+attrs+'>';
}
```

## F. ปรับการอ่านค่าฟอร์มและ click handler

แทน submit listener เดิมด้วย:
```javascript
$m.addEventListener('submit',function(e){
  e.preventDefault();
  var o={};
  F.fields.forEach(function(f){
    var value=f.t==='icon'||f.t==='color'?F.val[f.k]:
      f.t==='image'?F.up[f.k]:$('f-'+f.k).value;
    o[f.k]=f.pw?value:String(value||'').trim();
  });
  if(F.ok(o)===false)return;
  closeF();touch();
});
```

ภายใน `$m.addEventListener('click',function(e){...})` ให้เพิ่มหลังบรรทัด `if(e.target===$m){closeF();return;}`:
```javascript
var eye=e.target.closest('[data-toggle-pw]');
if(eye){
  var target=$(eye.dataset.togglePw);
  if(target){
    target.type=target.type==='password'?'text':'password';
    eye.textContent=target.type==='password'?'แสดง':'ซ่อน';
    eye.setAttribute('aria-label',target.type==='password'?'แสดงรหัสผ่าน':'ซ่อนรหัสผ่าน');
  }
  return;
}
var action=e.target.closest('[data-f="forgot"]');
if(action){
  var emailInput=$('f-email');
  forgotForm(emailInput?emailInput.value:'');
  return;
}
```

## G. ปรับ logout

แทนที่ case `logout` เดิมด้วย:
```javascript
case 'logout':
  if(dirty){msg='กดบันทึกหรือยกเลิกก่อนออกจากโหมดครู';renderBar();break;}
  window.TP_AUTH.signOut().then(function(){
    canSave=false;edit=false;render();
  }).catch(function(e){msg=errText(e);renderBar();});
  break;
```

## H. เพิ่มการกู้คืน Session ตอนเริ่มหน้าเว็บ

ก่อน `setInterval(...)` และ `loadRemote();` ช่วงท้ายของ IIFE ให้เพิ่ม:
```javascript
window.TP_AUTH.onAuthStateChange(function(event,session){
  if(event==='PASSWORD_RECOVERY')setTimeout(recoveryForm,0);
  if(event==='SIGNED_OUT'){canSave=false;edit=false;render();}
});

window.TP_AUTH.getSession().then(function(session){
  if(session){
    window.TP_AUTH.isAdmin().then(function(ok){
      if(ok){canSave=true;render();}
      else{window.TP_AUTH.signOut();}
    }).catch(function(){canSave=false;render();});
  }
}).catch(function(){});

if(new URLSearchParams(window.location.search).get('reset')==='1'){
  window.TP_AUTH.getSession().then(function(session){
    if(session)setTimeout(recoveryForm,0);
  });
}
```

หมายเหตุ: เปลี่ยน selector โฟกัสช่องแรกใน `form()` จาก
`input[type=text],input[type=password],select,textarea`
เป็น
`input[type=text],input[type=email],input[type=password],select,textarea`
เพื่อให้ฟอร์มล็อกอินโฟกัสช่องอีเมลก่อน
