Shader "Unlit/RedSphere"
{
    Properties
    {
        // inputs from gui, NB remember to also define them in "redeclaring" section
		[Toggle] _boolchooser("myBool", range(0,1)) = 0 // [Toggle] creates a checkbox in gui and give sit 0 or 1
		_floatchooser("myFloat", range(-1,1)) = 0
		_colorchooser("myColor", Color) = (1,0,0,1)
		_vec4chooser("myVec4", Vector) = (0,0,0,0)
		//_texturechooser("myTexture", 2D) = "" {} // "" er for bildefil, {} er for options
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
		    #pragma vertex vert
		    #pragma fragment frag

		    typedef vector <float, 3> vec3;  // to get more similar code to book
		    typedef vector <fixed, 3> col3;

		    //redeclaring ui inputs
		    int _boolchooser;
		    float _floatchooser;
		    float4 _colorchooser; // alternative use fixed4; range of -2.0 to +2.0 and 1/256th precision. (https://docs.unity3d.com/Manual/SL-DataTypesAndPrecision.html)
		    float4 _vec4chooser;
		    //sampler2D _texturechooser;

            // Structure for vertex data passed through the vertex shader
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            // Structure for data passed from the vertex shader to the fragment shader
            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
            };

            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            // Function to test for ray-sphere intersection
            float hit_sphere(float3 center, float radius, float3 ray_origin, float3 ray_direction)
            {
                float3 oc = ray_origin - center;
                float a = dot(ray_direction, ray_direction);
                float b = 2.0 * dot(oc, ray_direction);
                float c = dot(oc, oc) - radius * radius;
                float discriminant = b*b - 4*a*c;
                if (discriminant < 0) {
                    return -1.0;
                } 
                else {
                    return (-b - sqrt(discriminant)) / (2.0*a);
                }
            }

            vec3 color(vec3 ray_origin, vec3 ray_direction, v2f i) 
            {
                float t = hit_sphere(float3(0,0,-1), 0.5, ray_origin, ray_direction);
                if (t > 0.0) {
                    return vec3(1, 0, 0); // Sphere hit, color it red
                }
                vec3 unit_direction = normalize(ray_direction);
                float t_blend = 0.5 * (unit_direction.y + 1.0);
                return lerp(fixed4(1.0, 1.0, 1.0, 1.0), fixed4(0.5, 0.7, 1.0, 1.0), i.uv.y);
            }

            vec3 frag(v2f i) : SV_Target {
                vec3 origin = float3(0, 0, 0);
                vec3 lower_left_corner = float3(-2, -1, -1);
                vec3 horizontal = float3(4, 0, 0);
                vec3 vertical = float3(0, 2, 0);
                vec3 ray_direction = lower_left_corner + i.uv.x * horizontal + i.uv.y * vertical - origin;
                
                return vec3(color(origin, ray_direction, i));
            }
        ENDCG


        }
    }
}
