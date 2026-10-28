// Décor statique éclairé du guichet (BOOTH_SCENE §6, M9) : UN matériau pour
// tous les maillages fusionnés (`booth_static_near.res`, `booth_static_far.res`).
// Couches PBR AmbientCG (CC0) dans deux Texture2DArray :
//   albedo_rough = albédo (rgb, sRGB) + rugosité (a)
//   normal_metal = normale OpenGL (rg) + métal (b) + occlusion (a)
// Par sommet : UV = tuilage en mètres, UV2.x = couche (0 chrome usé,
// 1 tôles rivetées, 2 béton, 3 bandes de danger, 4 tôle perforée, 7 = aplat
// sans texture), UV2.y = mouillé (condensation qui ruisselle), COLOR.rgb =
// teinte, COLOR.a = facteur métal.
// Reflets : environnement analytique (plafonniers, néons du hall, intérieur du
// guichet côté agent) ajouté en émission selon métal / rugosité / Fresnel —
// pas de Sky ni de ReflectionProbe (en Compatibilité, un Sky posé pour les
// reflets s'affiche aussi en fond, constaté en M9).
// Qualité (BoothQuality) : `use_normal_maps`, `wet_motion` (0 = figé).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2DArray albedo_rough : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2DArray normal_metal : filter_linear_mipmap, repeat_enable;
uniform bool use_normal_maps = true;
uniform float wet_amount : hint_range(0.0, 1.0) = 1.0;
uniform float wet_motion : hint_range(0.0, 1.0) = 1.0;
uniform float reflection_strength = 1.0;
uniform vec3 env_floor : source_color = vec3(0.012, 0.014, 0.02);
uniform vec3 env_horizon : source_color = vec3(0.05, 0.058, 0.075);
uniform vec3 env_ceiling : source_color = vec3(0.07, 0.08, 0.1);
uniform vec3 env_teal : source_color = vec3(0.169, 0.431, 0.471);
uniform vec3 env_rose : source_color = vec3(0.494, 0.227, 0.361);
uniform vec3 env_halcyon : source_color = vec3(0.79, 0.72, 0.35);
uniform vec3 env_lamp : source_color = vec3(0.91, 0.945, 0.96);

varying vec3 world_pos;
varying vec3 world_nrm;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float lobe(vec3 d, vec3 axis, float power) {
	return pow(max(dot(d, normalize(axis)), 0.0), power);
}

// Environnement du hall (repère monde : agent en +Z, hall en −Z).
vec3 environment(vec3 d) {
	vec3 col = mix(env_floor, env_horizon, smoothstep(-0.4, 0.0, d.y));
	col = mix(col, env_ceiling, smoothstep(0.1, 0.7, d.y));
	col += vec3(0.23, 0.27, 0.34) * smoothstep(0.92, 1.0, sin(d.x * 18.0)) * smoothstep(0.35, 0.8, d.y) * 0.8;
	col += env_teal * lobe(d, vec3(-1.0, 0.25, -0.7), 10.0) * 1.4;
	col += env_rose * lobe(d, vec3(1.0, 0.15, -0.6), 10.0) * 1.3;
	col += env_halcyon * lobe(d, vec3(0.25, 0.25, -1.0), 30.0);
	// Intérieur du guichet : lampe, parois, plan de travail holographique.
	col += env_lamp * lobe(d, vec3(0.2, 0.7, 1.0), 24.0) * 0.7;
	col += vec3(0.16, 0.18, 0.21) * smoothstep(-0.1, 0.9, d.z);
	col += env_teal * lobe(d, vec3(0.0, -0.45, 1.0), 4.0) * 0.45;
	return col;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float layer = floor(UV2.x + 0.5);
	vec3 albedo = COLOR.rgb;
	float rough = 0.62;
	float metal = COLOR.a;
	float ao = 1.0;
	float spec = 0.5;
	if (layer > 6.5) {
		rough = 0.92; // aplats (silhouettes de la ville, affiches) : presque mats
		spec = 0.15;
	} else {
		vec4 a = texture(albedo_rough, vec3(UV, layer));
		vec4 n = texture(normal_metal, vec3(UV, layer));
		albedo = a.rgb * COLOR.rgb;
		rough = a.a;
		metal = n.b * COLOR.a;
		ao = n.a;
		if (use_normal_maps) {
			NORMAL_MAP = vec3(n.rg, 1.0);
			NORMAL_MAP_DEPTH = 1.0;
		}
	}
	// Condensation : film humide + filets qui descendent, faces verticales seulement.
	float wet = UV2.y * wet_amount * (1.0 - abs(world_nrm.y));
	if (wet > 0.001) {
		float u = (world_pos.x + world_pos.z) * 11.0;
		float h = hash12(vec2(floor(u), 3.7));
		float lane = smoothstep(0.5, 0.15, abs(fract(u) - 0.5)) * step(0.58, h);
		float y = fract(world_pos.y * 0.3 + TIME * wet_motion * (0.04 + 0.07 * h) + h * 7.0);
		float run = lane * smoothstep(0.05, 0.75, y) * (1.0 - smoothstep(0.92, 1.0, y));
		float w = clamp(wet * (0.3 + run), 0.0, 1.0);
		albedo *= mix(1.0, 0.6, w);
		rough = mix(rough, 0.06, w);
	}
	vec3 r = normalize((INV_VIEW_MATRIX * vec4(reflect(-VIEW, NORMAL), 0.0)).xyz);
	float gloss = (1.0 - rough) * (1.0 - rough);
	vec3 f0 = mix(vec3(0.04 * spec * 2.0), albedo, metal);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 5.0);
	EMISSION = environment(r) * (f0 + (1.0 - f0) * fres) * mix(0.15, 1.0, gloss) * reflection_strength * ao;
	ALBEDO = albedo;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = spec;
	AO = ao;
	AO_LIGHT_AFFECT = 0.35;
}
