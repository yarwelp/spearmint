attribute vec3 attr_Position;
attribute vec4 attr_TexCoord0;
attribute vec3 attr_Normal;

uniform vec4   u_DlightInfo;

#if defined(USE_DEFORM_VERTEXES)
uniform int    u_DeformGen;
uniform float  u_DeformParams[5];
uniform float  u_Time;
#endif

uniform vec4   u_Color;
uniform float  u_Intensity;
uniform float  u_LightRadius;
uniform mat4   u_ModelViewProjectionMatrix;

varying vec2   var_Tex1;
varying vec4   var_Color;

#if defined(USE_DEFORM_VERTEXES)
vec3 DeformPosition(const vec3 pos, const vec3 normal, const vec2 st)
{
	if (u_DeformGen == 0)
	{
		return pos;
	}

	float base =      u_DeformParams[0];
	float amplitude = u_DeformParams[1];
	float phase =     u_DeformParams[2];
	float frequency = u_DeformParams[3];
	float spread =    u_DeformParams[4];

	if (u_DeformGen == DGEN_BULGE)
	{
		phase *= st.x;
	}
	else // if (u_DeformGen <= DGEN_WAVE_INVERSE_SAWTOOTH)
	{
		phase += dot(pos.xyz, vec3(spread));
	}

	float value = phase + (u_Time * frequency);
	float func;

	if (u_DeformGen == DGEN_WAVE_SIN)
	{
		func = sin(value * 2.0 * M_PI);
	}
	else if (u_DeformGen == DGEN_WAVE_SQUARE)
	{
		func = sign(0.5 - fract(value));
	}
	else if (u_DeformGen == DGEN_WAVE_TRIANGLE)
	{
		func = abs(fract(value + 0.75) - 0.5) * 4.0 - 1.0;
	}
	else if (u_DeformGen == DGEN_WAVE_SAWTOOTH)
	{
		func = fract(value);
	}
	else if (u_DeformGen == DGEN_WAVE_INVERSE_SAWTOOTH)
	{
		func = (1.0 - fract(value));
	}
	else // if (u_DeformGen == DGEN_BULGE)
	{
		func = sin(value);
	}

	return pos + normal * (base + func * amplitude);
}
#endif

void main()
{
	vec3 position = attr_Position;
	vec3 normal = attr_Normal;

#if defined(USE_DEFORM_VERTEXES)
	position = DeformPosition(position, normal, attr_TexCoord0.st);
#endif

	gl_Position = u_ModelViewProjectionMatrix * vec4(position, 1.0);
		
	vec3 dist = u_DlightInfo.xyz - position;

	float dlightmod = 0;

	// ET global directed light
	if (u_LightRadius < 0)
	{
		var_Tex1 = vec2(0.0);

		dlightmod = u_Intensity * dot(u_DlightInfo.xyz, normal);
		// if two sided, make value absolute
		if (u_DlightInfo.a == 1 && dlightmod < 0) {
			dlightmod = -dlightmod;
		}
		dlightmod += u_Intensity * 0.125;

		if ( dlightmod < ( 1.0 / 128.0 ) )
		{
			dlightmod = 0;
		}

		dlightmod = clamp( dlightmod, 0.0, 1.0 );
	}
	// ET spherical dlight using vertex light
	else if (u_LightRadius > 0)
	{
		var_Tex1 = vec2(0.0);

		vec3 dir = vec3(u_LightRadius) - abs(dist);

		if (dir.x > 0 && dir.y > 0 && dir.z > 0)
		{
			dlightmod = clamp(u_Intensity * dir.x * dir.y * dir.z * u_DlightInfo.a, 0.0, 1.0);

			if ( dlightmod < ( 1.0 / 128.0 ) )
			{
				dlightmod = 0;
			}
		}
	}
	else
	{
		// Q3 cylinder dlight with texture
		var_Tex1 = dist.xy * u_DlightInfo.a + vec2(0.5);

		dlightmod = step(0.0, dot(dist, normal));
		dlightmod *= clamp(u_Intensity * 2.0 * (1.0 - abs(dist.z) * u_DlightInfo.a), 0.0, 1.0);
	}

	var_Color = u_Color * dlightmod;
}
