local function setupDropdown()
 dofile('tests/wow.lua');fakeUI();local A={};module('Skin',A);module('Dropdown',A)
 local selected
 local d=A.Skin.Dropdown(UIParent,{{value='ring',label='Ring'},{value='square',label='Square'},{value='none',label='None (icon only)'}},function(value) selected=value end)
 d:SetSize(170,26);d:SetValue('ring');return A,d,function() return selected end
end
test('dropdown opens choices without cycling and commits a clicked selection',function()
 local A,d,selected=setupDropdown();d.scripts.OnClick(d)
 eq(selected(),nil);eq(d:GetValue(),'ring');assert(A.Skin.dropdownMenu:IsShown())
 local row=A.Skin.dropdownMenu.rows[2];row.scripts.OnClick(row)
 eq(d:GetValue(),'square');eq(selected(),'square');eq(d.label:GetText(),'Square');eq(A.Skin.dropdownMenu:IsShown(),false)
 d:SetValue('none');eq(selected(),'square');eq(d.label:GetText(),'None (icon only)')
end)
test('dropdown closes on escape outside click disable and owner hide',function()
 local A,d=setupDropdown();d.scripts.OnClick(d);local menu=A.Skin.dropdownMenu
 menu.scripts.OnKeyDown(menu,'ESCAPE');eq(menu:IsShown(),false)
 d.scripts.OnClick(d);menu.IsMouseOver=function() return false end;d.IsMouseOver=function() return false end
 menu.scripts.OnEvent(menu,'GLOBAL_MOUSE_DOWN','LeftButton');eq(menu:IsShown(),false)
 d.scripts.OnClick(d);d:Disable();eq(menu:IsShown(),false)
 d:Enable();d.scripts.OnClick(d);d.scripts.OnHide(d);eq(menu:IsShown(),false)
end)
test('dropdown keyboard navigation and zero-valued options work',function()
 local A,d,selected=setupDropdown();d.scripts.OnClick(d);local menu=A.Skin.dropdownMenu
 menu.scripts.OnKeyDown(menu,'DOWN');menu.scripts.OnKeyDown(menu,'ENTER')
 eq(selected(),'square');eq(menu:IsShown(),false)
 local picked;local zero=A.Skin.Dropdown(UIParent,{{value=0,label='Never'},{value=20,label='20 yards'}},function(v) picked=v end)
 zero:SetSize(170,26);zero:SetValue(20);zero:SelectValue(0);eq(picked,0);eq(zero:GetValue(),0)
 eq(zero:SelectValue(999),false);eq(picked,0)
end)
