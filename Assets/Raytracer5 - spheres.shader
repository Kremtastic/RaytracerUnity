Shader "Unlit/NormalsShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
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
            #define INFINITY 1e8
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

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            #define MAX_SPHERES 2

            struct Sphere {
                float3 center;
                float radius;
            };

            // Define an array of spheres
            static const Sphere spheres[MAX_SPHERES] = {
                {float3(0, 0, -1), 0.5},
                {float3(0, -100.5, -1), 100} // Large sphere to act as ground
            };


            float hit_sphere(const Sphere sphere, float3 ray_origin, float3 ray_direction, out float3 hit_normal) 
            {
                float3 oc = ray_origin - sphere.center;
                float a = dot(ray_direction, ray_direction);
                float b = dot(oc, ray_direction);
                float c = dot(oc, oc) - sphere.radius * sphere.radius;
                float discriminant = b*b - a*c;
                if (discriminant > 0) {
                    float temp = (-b - sqrt(discriminant)) / a;
                    if (temp > 0.001) {
                        hit_normal = normalize((ray_origin + temp * ray_direction) - sphere.center);
                        return temp;
                    }
                }
                return -1.0;
            }



            fixed4 frag(v2f i) : SV_Target {
                float3 ray_origin = float3(0, 0, 0);

                float2 uv = i.uv * 2.0 - 1.0; // Transform UV to [-1, 1] range
                float3 ray_direction = normalize(float3(uv.x*2, uv.y, -1.0));
                float closest_t = INFINITY;
                float3 hit_normal;
                bool hit_anything = false;

                for (int j = 0; j < MAX_SPHERES; j++) {
                    float3 current_normal;
                    float t = hit_sphere(spheres[j], ray_origin, ray_direction, current_normal);
                    if (t > 0.0 && t < closest_t) {
                        closest_t = t;
                        hit_normal = current_normal; // Update normal for the closest hit
                        hit_anything = true;
                    }
                }


                if (hit_anything) {
                    return fixed4(hit_normal * 0.5 + 0.5, 1.0); // Color based on normal
                }
                // Background gradient
                return lerp(fixed4(1.0, 1.0, 1.0, 1.0), fixed4(0.5, 0.7, 1.0, 1.0), i.uv.y);
            }
            ENDCG
        }
    }
}
