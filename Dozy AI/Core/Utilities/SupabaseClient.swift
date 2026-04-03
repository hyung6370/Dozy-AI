//
//  SupabaseClient.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/3/26.
//

import Foundation
import Supabase

let supabase: SupabaseClient = {
    let info = Bundle.main.infoDictionary!
    let urlString = info["SUPABASE_URL"] as! String
    let key = info["SUPABASE_ANON_KEY"] as! String
    return SupabaseClient(
        supabaseURL: URL(string: urlString)!,
        supabaseKey: key
    )
}()
