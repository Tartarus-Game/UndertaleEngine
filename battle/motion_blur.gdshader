shader_type canvas_item;

uniform vec2 size;
uniform float scale;
uniform float angle;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture;

const float MAX_RAD = 32.0;

void fragment()
{
	vec4 Color = texture(SCREEN_TEXTURE,SCREEN_UV);
	float wei_tot = 1.0,wei;
	vec2 dir = vec2(cos(angle),-sin(angle))/size.xy;
	for(float d=1.0;d<MAX_RAD;d+=1.0)
	{
		if(d>scale)
		break;
		wei = 1.0;
		Color += wei * texture(SCREEN_TEXTURE,SCREEN_UV + dir * d);
		Color += wei * texture(SCREEN_TEXTURE,SCREEN_UV - dir * d);
		wei_tot += wei + wei;
	}
	Color /= wei_tot;
	COLOR = Color;
}