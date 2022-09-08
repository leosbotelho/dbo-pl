import { batch } from ""

const batch_New_Token_or_Prov_Sel = batch("New_Token_or_Prov_Sel", [
  ["Par_DbToken_Hash", 2]
])

const batch_Token_Add = batch("Token_Add", [
  ["Par_Token_Add", 9],
  ["Par_Token_Add_O", 4]
])

const batch_Token_Seen = batch("Token_Seen", [["Par_Token_Hash", 1]])

const batch_GithubTokenProv_Add = batch("GithubTokenProv_Add", [
  ["Par_Token_Hash", 1]
])

const batch_CgTlTokenProv_Add = batch("CgTlTokenProv_Add", [
  ["Par_Token_Hash", 1]
])

const batch_TgTokenProvBlock_Add = batch("TgTokenProvBlock_Add", [
  ["Par_Token_Hash", 1]
])
