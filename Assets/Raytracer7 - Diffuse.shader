Shader "Unlit/DiffuseMaterial"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        // inputs from gui, NB remember to also define them in "redeclaring" section
		[Toggle] _boolchooser("myBool", range(0,1)) = 0 // [Toggle] creates a checkbox in gui and give sit 0 or 1
		_floatchooser("myFloat", range(-1,1)) = 0
		_colorchooser("myColor", Color) = (1,0,0,1)
		_vec4chooser("myVec4", Vector) = (0,0,0,0)
        _NumSamples("Rays Per Pixel: ", Range(1, 75)) = 16
		//_texturechooser("myTexture", 2D) = "" {} // "" er for bildefil, {} er for options
        _PctReflectivity("Reflectivity%", Range(0,1)) = 0.5 // Default to 50% reflectivity
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
            #define MAX_SPHERES 2

		    #pragma vertex vert
		    #pragma fragment frag

		    typedef vector <float, 3> vec3;  // to get more similar code to book
		    typedef vector <fixed, 3> col3;

		    //redeclaring ui inputs
		    int _boolchooser;
		    float _floatchooser;
		    float4 _colorchooser; // alternative use fixed4; range of -2.0 to +2.0 and 1/256th precision. (https://docs.unity3d.com/Manual/SL-DataTypesAndPrecision.html)
		    float4 _vec4chooser;
            float _PctReflectivity;
            float _NumSamples;
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

            struct Sphere {
                float3 center;
                float radius;
            };

            // Define an array of spheres
            static const Sphere spheres[MAX_SPHERES] = {
                
                {float3(0, -100.5, -1), 100}, // Ground
                {float3(0, 0, -1), 0.5} // Center sphere
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

            // Improved random function from previous shader (Antialiasing should look better too)
            float random(float2 uv, int s) {
                float2 seed = float2(dot(uv, float2(12.9898, 78.233)) + s, dot(uv, float2(24.8793, 76.233)) + s);
                seed = frac(sin(seed) * 43758.5453);
                return seed.x + seed.y;
            }


            // Generates a random point inside a unit sphere
            vec3 random_in_unit_sphere(float2 uv, int s) {
                vec3 p;
                do {
                    // Creates a random point in a unit cube and scales it to a unit sphere
                    p = 2.0 * vec3(random(uv, s), random(uv + 1.0, s), random(uv + 2.0, s)) - vec3(1.0, 1.0, 1.0);
                } while (dot(p, p) >= 1.0); // Repeat until the point is inside the unit sphere
                return p;
            }

            vec3 color(const vec3 ray_origin, const vec3 ray_direction, float2 uv, int s) {
                vec3 accumulated_color = vec3(0.0, 0.0, 0.0);
                vec3 attenuation = vec3(1.0, 1.0, 1.0); // Start with no attenuation
                vec3 current_ray_origin = ray_origin;
                vec3 current_ray_direction = ray_direction;

                for (int i = 0; i < NUM_SAMPLES; ++i) {
                    float hit_distance = INFINITY;
                    vec3 hit_normal;
                    bool hit = false;

                    // Check for sphere intersections
                    for (int j = 0; j < MAX_SPHERES; ++j) {
                        float distance = hit_sphere(spheres[j], current_ray_origin, current_ray_direction, hit_normal);
                        if (distance > 0.0 && distance < hit_distance) {
                            hit_distance = distance;
                            hit = true;
                        }
                    }

                    // Update ray origin and direction based on the hit
                    if (hit) {
                        vec3 hit_point = current_ray_origin + hit_distance * current_ray_direction;
                        vec3 target = hit_point + hit_normal + random_in_unit_sphere(uv, s); // For diffuse material
                        current_ray_direction = normalize(target - hit_point);
                        current_ray_origin = hit_point + 0.001 * hit_normal; // Avoid self-intersection

                        
                        attenuation *= _PctReflectivity;

                    } else {
                        // Sky gradient
                        vec3 unit_direction = normalize(current_ray_direction);
                        float t = 0.5 * (unit_direction.y + 1.0);
                        vec3 sky_color = (1.0 - t) * vec3(1.0, 1.0, 1.0) + t * vec3(0.5, 0.7, 1.0);
                        accumulated_color += attenuation * sky_color;
                        break; // No more intersections, break the loop
                    }
                }

                return accumulated_color;
            }

            vec3 frag(v2f i) : SV_TARGET {
                vec3 color_accumulated = vec3(0, 0, 0);
                vec3 ray_origin = vec3(0, 0, 0); // Camera origin
                // Antialiasing loop
                for (int s = 0; s < _NumSamples; ++s) {
                    float2 jitter = (random(i.uv * float(s), s) - 0.5) * 2.0 / float(_ScreenParams.y);
                    float2 uv = i.uv * 2.0 - 1.0 + jitter;
                    vec3 ray_direction = normalize(vec3(uv.x*2, uv.y, -1.0));
                    color_accumulated += color(ray_origin, ray_direction, i.uv, s);
                }
                vec3 final_color = color_accumulated / float(_NumSamples);
                return fixed4(final_color, 1.0);
            }
       ENDCG

       }
    }
}
