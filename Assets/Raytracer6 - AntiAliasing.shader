Shader "Unlit/AntiAliasing"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        [Toggle] _boolchooser("myBool", range(0,1)) = 0 
        _floatchooser("myFloat", range(-1,1)) = 0
        _colorchooser("myColor", Color) = (1,0,0,1)
        _vec4chooser("myVec4", Vector) = (0,0,0,0)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #define INFINITY 1e8
            #define NUM_SAMPLES 4
            #pragma vertex vert
            #pragma fragment frag

            typedef vector <float, 3> vec3;  // To keep code more similar to the book

            // Redeclaring UI inputs
            int _boolchooser;
            float _floatchooser;
            float4 _colorchooser;
            float4 _vec4chooser;

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
                vec3 center;
                float radius;
            };

            static const Sphere spheres[MAX_SPHERES] = {
                {vec3(0, 0, -1), 0.5},
                {vec3(0, -100.5, -1), 100} // Large sphere to act as ground
            };

            float hit_sphere(const Sphere sphere, vec3 ray_origin, vec3 ray_direction, out vec3 hit_normal) 
            {
                vec3 oc = ray_origin - sphere.center;
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

            float rand(in float2 uv)
            {
                float2 mixUV = float2(dot(uv, float2(127.1, 311.7)), dot(uv, float2(269.5, 183.3)));
                mixUV = frac(sin(mixUV) * 43758.5453);
                return frac(sin(dot(mixUV, float2(12.9898, 78.233))) * 43758.5453);
            }

            fixed4 color(const vec3 ray_origin, const vec3 ray_direction, const v2f i) {
                float closest_t = INFINITY;
                vec3 hit_normal;
                bool hit_anything = false;

                for (int j = 0; j < MAX_SPHERES; j++) {
                    vec3 current_normal;
                    float t = hit_sphere(spheres[j], ray_origin, ray_direction, current_normal);
                    if (t > 0.0 && t < closest_t) {
                        closest_t = t;
                        hit_normal = current_normal; // Update normal for the closest hit
                        hit_anything = true;
                    }
                }

                if (hit_anything) {
                    return fixed4(hit_normal * 0.5 + 0.5, 1); // Color based on normal
                }
                // Sky gradient
                return lerp(fixed4(1.0, 1.0, 1.0, 1.0), fixed4(0.5, 0.7, 1.0, 1.0), i.uv.y);
            }

            vec3 frag(v2f i) : SV_Target {
                vec3 accumulated_color = vec3(0.0, 0.0, 0.0);
                vec3 ray_origin = vec3(0.0, 0.0, 0.0);

                for (int s = 0; s < NUM_SAMPLES; ++s) {
                    float2 jitter = (rand(i.uv * float(s)) - 0.5) * 2.0 / float(_ScreenParams.y);
                    float2 uv_jittered = i.uv + jitter;
                    float2 uv = uv_jittered * 2.0 - 1.0;
        
                    vec3 ray_direction = normalize(vec3(uv.x*2, uv.y, -1.0));

                    vec3 sample_color = color(ray_origin, ray_direction, i);
                    accumulated_color += vec3(sample_color.r, sample_color.g, sample_color.b);
                }

                vec3 final_color = accumulated_color / float(NUM_SAMPLES);
                return fixed4(final_color, 1.0);
            }


            ENDCG
        }
    }
}

