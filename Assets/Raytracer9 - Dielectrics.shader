Shader "Unlit/FinalShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        // Camera
        _cameraPosX("Camera Pos x: ", range(-2,2)) = 0
        _cameraPosY("Camera Pos y: ", range(-0.5,3)) = 0
        _cameraPosZ("Camera Pos z: ", range(0,1)) = 0
         // Lookat
        _LookAtPosX("Lookat Pos x: ", range(-1,1)) = 0
        _LookAtPosY("Lookat Pos y: ", range(-2,2)) = 0
        _LookAtPosZ("Lookat Pos z: ", range(-2,-0.1)) = -0.5
        _FOV("FOV: ", range(0,150)) = 90

        _moveSpherePosX("Move Sphere (x-axis): ", range(-2,2)) = 2
        _NumSamples("Rays Per Pixel: ", Range(1, 75)) = 16  // Rays Per Pixels (samples)
        _MaxBounces("Max Bounces", Range(0, 30)) = 5  // Bounces
        _refractionIndex("Refraction Index: ", range(-1.5,1.5)) = 1.5

		_vec4chooser("myVec4", Vector) = (0,0,0,0)
        _PctReflectivity("Reflectivity%", Range(0,1)) = 1.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #define INFINITY 1e8
            #define MAX_SPHERES 5

		    #pragma vertex vert
		    #pragma fragment frag

		    typedef vector <float, 3> vec3;  // to get more similar code to book
		    typedef vector <fixed, 3> col3;
            typedef vector <float, 4> vec4;

		    //redeclaring ui inputs
		    int _boolchooser;
		    float _floatchooser;
		    float4 _colorchooser; // alternative use fixed4; range of -2.0 to +2.0 and 1/256th precision. (https://docs.unity3d.com/Manual/SL-DataTypesAndPrecision.html)
		    float4 _vec4chooser;
            float _PctReflectivity;
            float _cameraLookatPos;
            float _moveSpherePosX;
            int _NumSamples;
            int _MaxBounces;
            float _refractionIndex;

            // Camera
            float _cameraPosX;
            float _cameraPosY;
            float _cameraPosZ;
            // Lookat
            float _LookAtPosX;
            float _LookAtPosY;
            float _LookAtPosZ;
            float _FOV;

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
                {float3( 0.0, -100.5, -1.0), 100.0},  // Ground
                {float3( 0.0,    0.0, -1.0),   0.5},  // Center sphere (Lambertian)
                {float3(-1.0,    0.0, -1.0),   0.5},  // Left sphere (Dielectric)
                {float3(-1.0,    0.0, -1.0),  -0.4},  // Left sphere (Dielectric)
                {float3( 1.0,    0.0, -1.0),   0.5}   // Right sphere (Metallic)
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

            // Random function
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

            vec3 reflect(const vec3 v, const vec3 n) {
                return v - 2.0 * dot(v, n) * n;
            }

            // Refract based on Snell's Law
            bool refract(const vec3 uv, const vec3 n, float ni_over_nt, out vec3 refracted) {
                float cos_theta = min(dot(-uv, n), 1.0f);
                float3 r_out_perp =  ni_over_nt * (uv + cos_theta * n);
                float3 r_out_parallel = -sqrt(abs(1.0f - dot(r_out_perp, r_out_perp))) * n;
                refracted = r_out_perp + r_out_parallel;
                return dot(refracted, refracted) > 0; // True if refraction occurred
            }

            // Schlick's approximation for reflectance
            float schlick(float cosine, float ref_idx) {
                float r0 = (1.0 - ref_idx) / (1.0 + ref_idx);
                r0 = r0 * r0;
                return r0 + (1.0 - r0) * pow((1.0 - cosine), 5.0);
            }

            // Adjusted color function to handle different materials
            vec3 color(const vec3 ray_origin, const vec3 ray_direction, float2 uv, int s) {
                    vec3 accumulated_color = vec3(0, 0, 0); // Accumulate color here
                    vec3 current_ray_origin = ray_origin;
                    vec3 current_ray_direction = ray_direction;
                    vec3 attenuation = vec3(1.0, 1.0, 1.0); // Start with full color, attenuate with each bounce
                    float ir = 1.0; // Vacuum's index of refraction as default
    
                for (int bounce = 0; bounce < _MaxBounces; bounce++) {
                    float hit_distance = INFINITY;
                    vec3 hit_normal;
                    bool hit = false;
                    vec3 albedo = vec3(0.0, 0.0, 0.0);
                    bool METALLIC = false;
                    bool DIELECTRIC = false;

                    // Sphere logic
                    for (int j = 0; j < MAX_SPHERES; j++) {
                        float distance = hit_sphere(spheres[j], current_ray_origin, current_ray_direction, hit_normal);

                        if (distance > 0.001f && distance < hit_distance) {
                            hit_distance = distance;
                            hit = true;
                
                            // Assign colors to spheres
                            if (j == 0) // Ground
                            { 
                                albedo = col3(0.8, 0.8, 0.0);
                            } 
                            else if (j == 1) // Center Sphere
                            { 
                                albedo = col3(0.1, 0.2, 0.5);
                            } 
                            else if (j == 2) // Left Dielectric Sphere
                            { 
                                albedo = col3(0.8, 0.8, 0.8);
                                DIELECTRIC = true;
                                ir = _refractionIndex; // Index of refraction for glass
                            }
                            else if (j == 3) // Left Dielectric Sphere
                            { 
                                albedo = col3(0.8, 0.8, 0.8);
                                DIELECTRIC = true;
                                ir = _refractionIndex; // Index of refraction for glass
                            }
                            else if (j == 4) // Right Metallic Sphere
                            {
                                albedo = col3(0.8, 0.6, 0.2);
                                METALLIC = true;
                            }
                        }
                    }

                    if (hit) {
                        vec3 hit_point = current_ray_origin + hit_distance * current_ray_direction;
                        bool isFrontFace = dot(current_ray_direction, hit_normal) < 0;
                        vec3 outward_normal = isFrontFace ? hit_normal : -hit_normal;
                        
                        if (METALLIC) {
                            // Metallic
                            float fuzziness = 0.0f;
                            vec3 reflected_direction = reflect(current_ray_direction, hit_normal);
                            vec3 fuzz_direction = fuzziness * random_in_unit_sphere(uv, s);
                            current_ray_direction = normalize(reflected_direction + fuzz_direction);

                            attenuation = albedo * _PctReflectivity;


                        } else if (DIELECTRIC) {
                            // Dielectric
                            float refractionRatio = isFrontFace ? (1 / ir) : ir;
                            vec3 refracted;
                            bool canRefract = refract(current_ray_direction, outward_normal, refractionRatio, refracted);

                            vec3 reflect_dir = reflect(current_ray_direction, hit_normal);
                            vec3 refract_dir;
                            float reflect_prob;
                            if (canRefract) {
                                float cos_theta = dot(-current_ray_direction, outward_normal);
                                float sin_theta = sqrt(1.0 - cos_theta*cos_theta);
                                reflect_prob = schlick(cos_theta, ir);
                                refract_dir = refracted;
                            } else {
                                // Total internal reflection
                                reflect_prob = 1.0;
                            }
                            if (random(uv, s) < reflect_prob) {
                                current_ray_direction = reflect_dir;
                            } else {
                                current_ray_direction = refract_dir;
                            }
                            //attenuation *= albedo;
                            attenuation = 1;  // Glass surface absorbs nothing.
                            current_ray_origin = hit_point + 0.001 * outward_normal; // Small offset to avoid self-intersection

                        } else {
                            // Lambertian
                            vec3 target = hit_point + outward_normal + random_in_unit_sphere(uv, s);
                            current_ray_origin = hit_point + 0.001 * outward_normal;
                            current_ray_direction = normalize(target - current_ray_origin);
                            attenuation *= albedo * _PctReflectivity;
                        }
                    } else {
                        // Sky color
                        float t = 0.5f * (normalize(current_ray_direction).y + 1.0f);
                        vec3 sky_color = (1.0f - t) * col3(1.0, 1.0, 1.0) + t * col3(0.5, 0.7, 1.0);
                        accumulated_color = sky_color;
                        break;
                    }

                }
                return accumulated_color * attenuation; // Apply attenuation last to affect overall color
            }


            vec4 frag(v2f i) : SV_TARGET {
                vec3 color_accumulated = col3(0, 0, 0);
                vec3 ray_origin = vec3(1 * _cameraPosX, 1 * _cameraPosY, 1 * _cameraPosZ); // Camera origin

                /* --  Camera code -- */
                vec3 lookAtPos = vec3(_LookAtPosX, _LookAtPosY, _LookAtPosZ);
                vec3 up = vec3(0, 1, 0);
                // Camera basis vectors
                vec3 forward = normalize(lookAtPos - ray_origin);
                vec3 right = normalize(cross(forward, up));
                vec3 cameraUp = cross(right, forward);

                // FOV and Aspect Ratio
                float fov = radians(_FOV); 
                float aspectRatio = _ScreenParams.x / _ScreenParams.y;
                float halfHeight = tan(fov / 2.0);
                float halfWidth = aspectRatio * halfHeight;

                // Adjust right and up vectors based on FOV and aspect ratio
                right = right * halfWidth;
                cameraUp = cameraUp * halfHeight;
                /* --              -- */

                // Antialiasing loop
                for (int s = 0; s < _NumSamples; s++) {
                    float2 jitter = (random(i.uv * float(s), s) - 0.5) * 2.0 / float(_ScreenParams.y);
                    float2 uv = i.uv * 2.0 - 1.0 + jitter;
                    vec3 ray_direction = normalize(forward + uv.x * right + uv.y * cameraUp);
                    color_accumulated += color(ray_origin, ray_direction, i.uv, s);
                }

                vec3 final_color = color_accumulated / _NumSamples;

                final_color.r = pow(final_color.r, 1.0 / 2.2);
                final_color.g = pow(final_color.g, 1.0 / 2.2);
                final_color.b = pow(final_color.b, 1.0 / 2.2);

                return vec4(final_color, 1.0);
            }
            ENDCG

       }
    }
}
